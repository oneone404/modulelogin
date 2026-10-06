#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define STB_IMAGE_IMPLEMENTATION
#include "third_party/stb_image.h"

struct Image {
    unsigned width = 0;
    unsigned height = 0;
    std::vector<unsigned char> rgba;
};

static bool capture_screen(Image& image) {
    int fds[2];
    if (pipe(fds) != 0) return false;
    pid_t pid = fork();
    if (pid == 0) {
        dup2(fds[1], STDOUT_FILENO);
        close(fds[0]);
        close(fds[1]);
        execl("/system/bin/screencap", "screencap", static_cast<char*>(nullptr));
        _exit(127);
    }
    close(fds[1]);
    FILE* stream = fdopen(fds[0], "r");
    if (!stream) { close(fds[0]); return false; }

    uint32_t header[4] = {};
    if (fread(header, sizeof(header), 1, stream) != 1 || header[0] == 0 || header[1] == 0) {
        fclose(stream);
        waitpid(pid, nullptr, 0);
        return false;
    }

    image.width = header[0];
    image.height = header[1];
    const size_t bytes = static_cast<size_t>(image.width) * image.height * 4;
    image.rgba.resize(bytes);
    const bool ok = fread(image.rgba.data(), 1, bytes, stream) == bytes;
    fclose(stream);
    waitpid(pid, nullptr, 0);
    return ok;
}

static void tap_screen(int x, int y) {
    pid_t pid = fork();
    if (pid != 0) { waitpid(pid, nullptr, 0); return; }
    char sx[16], sy[16];
    std::snprintf(sx, sizeof(sx), "%d", x);
    std::snprintf(sy, sizeof(sy), "%d", y);
    execl("/system/bin/input", "input", "tap", sx, sy, static_cast<char*>(nullptr));
    _exit(127);
}

static bool load_png(const char* path, Image& image) {
    int width = 0, height = 0, channels = 0;
    unsigned char* data = stbi_load(path, &width, &height, &channels, 4);
    if (!data || width <= 0 || height <= 0) {
        std::fprintf(stderr, "STBI_ERROR %s\n", stbi_failure_reason());
        return false;
    }
    image.width = static_cast<unsigned>(width);
    image.height = static_cast<unsigned>(height);
    image.rgba.assign(data, data + static_cast<size_t>(width) * height * 4);
    stbi_image_free(data);
    return true;
}

static inline unsigned pixel_diff(const unsigned char* a, const unsigned char* b) {
    return static_cast<unsigned>(std::abs(int(a[0]) - int(b[0]))) +
           static_cast<unsigned>(std::abs(int(a[1]) - int(b[1]))) +
           static_cast<unsigned>(std::abs(int(a[2]) - int(b[2])));
}

static double match_at(const Image& screen, const Image& templ, int x, int y,
                       uint64_t reject_limit, double best_score) {
    uint64_t diff = 0;
    uint64_t compared = 0;

    // Cheap, evenly distributed rejection pass. Most positions fail here.
    const int grid_x = std::max(1u, templ.width / 4);
    const int grid_y = std::max(1u, templ.height / 4);
    for (unsigned ty = grid_y / 2; ty < templ.height; ty += grid_y) {
        for (unsigned tx = grid_x / 2; tx < templ.width; tx += grid_x) {
            const unsigned char* t = &templ.rgba[(static_cast<size_t>(ty) * templ.width + tx) * 4];
            if (t[3] < 16) continue;
            const unsigned char* s = &screen.rgba[(static_cast<size_t>(y + ty) * screen.width + x + tx) * 4];
            diff += pixel_diff(s, t);
            compared++;
        }
    }
    if (compared && diff > reject_limit * compared / (static_cast<uint64_t>(templ.width) * templ.height)) return -1.0;

    diff = 0;
    uint64_t active = 0;
    for (unsigned ty = 0; ty < templ.height; ++ty) {
        const unsigned char* s = &screen.rgba[(static_cast<size_t>(y + ty) * screen.width + x) * 4];
        const unsigned char* t = &templ.rgba[static_cast<size_t>(ty) * templ.width * 4];
        for (unsigned tx = 0; tx < templ.width; ++tx, s += 4, t += 4) {
            if (t[3] < 16) continue;
            diff += pixel_diff(s, t);
            active++;
            if ((active & 255u) == 0 && diff > reject_limit) return -1.0;
        }
    }
    if (!active) return -1.0;
    return 1.0 - static_cast<double>(diff) / static_cast<double>(active * 3ull * 255ull);
}

struct MatchResult { double score = -1.0; int x = -1; int y = -1; };

static MatchResult find_template(const Image& screen, const Image& templ, double threshold,
                                 bool has_region, int rx, int ry, int rw, int rh) {
    MatchResult result;
    if (templ.width > screen.width || templ.height > screen.height) return result;
    int x0 = 0, y0 = 0;
    int x1 = static_cast<int>(screen.width - templ.width);
    int y1 = static_cast<int>(screen.height - templ.height);
    if (has_region) {
        // Region constrains the resulting match center, matching the legacy CLI semantics.
        const int half_w = static_cast<int>(templ.width / 2);
        const int half_h = static_cast<int>(templ.height / 2);
        x0 = std::max(0, rx - half_w);
        y0 = std::max(0, ry - half_h);
        x1 = std::min(x1, rx + rw - half_w);
        y1 = std::min(y1, ry + rh - half_h);
    }
    if (x1 < x0 || y1 < y0) return result;
    const uint64_t pixels = static_cast<uint64_t>(templ.width) * templ.height;
    const uint64_t reject_limit = static_cast<uint64_t>((1.0 - threshold) * pixels * 3.0 * 255.0);
    for (int y = y0; y <= y1; ++y) {
        for (int x = x0; x <= x1; ++x) {
            const double score = match_at(screen, templ, x, y, reject_limit, result.score);
            if (score > result.score) { result.score = score; result.x = x; result.y = y; }
        }
    }
    return result;
}

struct BatchSpec {
    const char* tag;
    const char* file;
    double threshold;
    bool region;
    int x, y, w, h;
};

static int run_batch(const char* image_dir, bool click, const char* screen_path) {
    Image screen;
    if (!(screen_path ? load_png(screen_path, screen) : capture_screen(screen))) {
        std::fprintf(stderr, "ERROR_CAPTURE_SCREEN\n"); return 4;
    }
    const BatchSpec specs[] = {
        {"BALO", "nut_balo.png", 0.94, true, 860, 240, 100, 140},
        {"LOGIN", "nut_dang_nhap.png", 0.94, true, 350, 140, 260, 100},
        {"CONFIRM", "nut_xac_nhan.png", 0.95, true, 470, 345, 240, 130},
        {"OK", "nut_ok.png", 0.95, true, 350, 345, 260, 130},
        {"MENU", "tat_menu.png", 0.98, true, 660, 25, 170, 155},
    };
    const BatchSpec* winner = nullptr;
    MatchResult best;
    Image winner_template;
    for (const BatchSpec& spec : specs) {
        std::string path = std::string(image_dir) + "/" + spec.file;
        Image templ;
        if (!load_png(path.c_str(), templ)) continue;
        MatchResult match = find_template(screen, templ, spec.threshold, spec.region, spec.x, spec.y, spec.w, spec.h);
        if (match.x >= 0 && match.score >= spec.threshold && (!winner || match.score > best.score)) {
            winner = &spec;
            best = match;
            winner_template = std::move(templ);
        }
    }
    if (winner) {
        const int cx = best.x + static_cast<int>(winner_template.width / 2);
        const int cy = best.y + static_cast<int>(winner_template.height / 2);
        std::printf("FOUND %s %d %d %.2f\n", winner->tag, cx, cy, best.score);
        if (click) tap_screen(cx, cy);
        return 0;
    }
    std::printf("NOT_FOUND 0.00\n");
    return 1;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "Usage: oneone_finder_v2 <template.png> [threshold] [--click] [--region x,y,w,h]\n       oneone_finder_v2 --batch <image-dir> [--click]\n");
        return 2;
    }

    if (std::strcmp(argv[1], "--batch") == 0) {
        if (argc < 3) return 2;
        bool click = false;
        const char* screen_path = nullptr;
        for (int i = 3; i < argc; ++i) {
            if (std::strcmp(argv[i], "--click") == 0) click = true;
            else if (std::strcmp(argv[i], "--screen") == 0 && i + 1 < argc) screen_path = argv[++i];
        }
        return run_batch(argv[2], click, screen_path);
    }

    const char* template_path = argv[1];
    double threshold = 0.85;
    bool click = false;
    bool has_region = false;
    const char* screen_path = nullptr;
    int rx = 0, ry = 0, rw = 0, rh = 0;

    for (int i = 2; i < argc; ++i) {
        if (std::strcmp(argv[i], "--click") == 0) click = true;
        else if (std::strcmp(argv[i], "--region") == 0 && i + 1 < argc) {
            has_region = std::sscanf(argv[++i], "%d,%d,%d,%d", &rx, &ry, &rw, &rh) == 4;
        } else if (std::strcmp(argv[i], "--screen") == 0 && i + 1 < argc) {
            screen_path = argv[++i];
        } else {
            char* end = nullptr;
            const double value = std::strtod(argv[i], &end);
            if (end && *end == '\0') threshold = value;
        }
    }
    threshold = std::max(0.0, std::min(1.0, threshold));

    Image templ, screen;
    if (!load_png(template_path, templ)) {
        std::fprintf(stderr, "ERROR_LOAD_TEMPLATE %s\n", template_path);
        return 3;
    }
    if (!(screen_path ? load_png(screen_path, screen) : capture_screen(screen))) {
        std::fprintf(stderr, "ERROR_CAPTURE_SCREEN\n");
        return 4;
    }
    MatchResult match = find_template(screen, templ, threshold, has_region, rx, ry, rw, rh);

    if (match.x >= 0 && match.score >= threshold) {
        const int cx = match.x + static_cast<int>(templ.width / 2);
        const int cy = match.y + static_cast<int>(templ.height / 2);
        std::printf("FOUND %d %d %.2f\n", cx, cy, match.score);
        if (click) tap_screen(cx, cy);
        return 0;
    }

    std::printf("NOT_FOUND %.2f\n", std::max(0.0, match.score));
    return 1;
}
