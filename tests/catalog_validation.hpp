#pragma once

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace airwindohhs_godot::validation {

struct Report {
    std::size_t effects = 0;
    std::size_t renders = 0;
    std::vector<std::string> failures;
};

struct ParameterRange {
    int index;
    float minimum;
    float maximum;
};

enum class Fixture { silence, impulse, noise, musical };

inline float fixture_sample(Fixture fixture, std::size_t frame, float sample_rate,
                            std::uint32_t& noise_state) {
    constexpr double kPi = 3.14159265358979323846;
    switch (fixture) {
    case Fixture::silence: return 0.0f;
    case Fixture::impulse: return frame == 0 ? 0.5f : 0.0f;
    case Fixture::noise:
        noise_state = noise_state * 1664525u + 1013904223u;
        return (static_cast<float>((noise_state >> 8u) & 0xffffu) / 32767.5f - 1.0f) * 0.25f;
    case Fixture::musical: {
        const double time = static_cast<double>(frame) / sample_rate;
        return static_cast<float>(0.2 * std::sin(2.0 * kPi * 220.0 * time) +
                                  0.1 * std::sin(2.0 * kPi * 329.6276 * time));
    }
    }
    return 0.0f;
}

template <typename Effect>
bool render_once(float sample_rate, std::size_t frame_count, Fixture fixture,
                 float parameter_override, int override_index) {
    constexpr std::size_t kMaximumFrames = 257;
    if (frame_count > kMaximumFrames) return false;
    Effect effect;
    effect.setSampleRate(sample_rate);
    for (int parameter = 0; parameter < Effect::kNumParameters; ++parameter)
        effect.set_parameter_value(parameter,
            parameter == override_index ? parameter_override : effect.get_parameter_default(parameter));

    std::array<float, kMaximumFrames> input_left{};
    std::array<float, kMaximumFrames> input_right{};
    std::array<float, kMaximumFrames> output_left{};
    std::array<float, kMaximumFrames> output_right{};
    std::uint32_t noise_state = 0x12345678u;
    for (std::size_t frame = 0; frame < frame_count; ++frame) {
        input_left[frame] = fixture_sample(fixture, frame, sample_rate, noise_state);
        input_right[frame] = fixture_sample(fixture, frame + 7u, sample_rate, noise_state);
    }
    float* inputs[] = {input_left.data(), input_right.data()};
    float* outputs[] = {output_left.data(), output_right.data()};
    effect.process(inputs, outputs, static_cast<long>(frame_count));
    for (std::size_t frame = 0; frame < frame_count; ++frame) {
        if (!std::isfinite(output_left[frame]) || !std::isfinite(output_right[frame])) return false;
        if (std::abs(output_left[frame]) > 1.0e12f || std::abs(output_right[frame]) > 1.0e12f)
            return false;
    }
    return true;
}

template <typename Effect>
void validate_effect(const char* effect_id, Report& report,
                     std::initializer_list<ParameterRange> overrides = {}) {
    ++report.effects;
    constexpr std::array<float, 3> sample_rates{44100.0f, 48000.0f, 96000.0f};
    constexpr std::array<std::size_t, 4> callback_sizes{1u, 17u, 64u, 257u};
    constexpr std::array<Fixture, 4> fixtures{
        Fixture::silence, Fixture::impulse, Fixture::noise, Fixture::musical};
    for (float rate : sample_rates) {
        for (auto size : callback_sizes) {
            for (auto fixture : fixtures) {
                ++report.renders;
                if (!render_once<Effect>(rate, size, fixture, 0.0f, -1)) {
                    report.failures.emplace_back(std::string(effect_id) + ": non-finite/default render");
                    return;
                }
            }
        }
    }
    for (int parameter = 0; parameter < Effect::kNumParameters; ++parameter) {
        float minimum = 0.0f;
        float maximum = 1.0f;
        for (const auto& range : overrides) {
            if (range.index == parameter) {
                minimum = range.minimum;
                maximum = range.maximum;
            }
        }
        for (float value : {minimum, maximum}) {
            ++report.renders;
            if (!render_once<Effect>(48000.0f, 257u, Fixture::musical, value, parameter)) {
                report.failures.emplace_back(std::string(effect_id) + ": parameter extremum failed");
                return;
            }
        }
    }
}

} // namespace airwindohhs_godot::validation
