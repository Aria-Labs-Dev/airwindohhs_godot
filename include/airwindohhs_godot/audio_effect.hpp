#pragma once

#include <airwindohhs_godot/parameter_state.hpp>

#include <godot_cpp/classes/audio_effect.hpp>
#include <godot_cpp/classes/audio_effect_instance.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/list.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string_view>
#include <vector>

namespace airwindohhs_godot {

class Processor {
public:
    virtual ~Processor() = default;
    virtual std::size_t parameter_count() const noexcept = 0;
    virtual void set_parameter(std::size_t index, float value) noexcept = 0;
    virtual void process(const godot::AudioFrame* source, godot::AudioFrame* destination,
                         std::int32_t frame_count) noexcept = 0;
};

template <typename Effect>
class ProcessorModel final : public Processor {
public:
    static constexpr std::size_t kChunkFrames = 256;

    explicit ProcessorModel(float sample_rate) {
        effect_.setSampleRate(sample_rate);
    }

    std::size_t parameter_count() const noexcept override {
        return static_cast<std::size_t>(Effect::kNumParameters);
    }

    void set_parameter(std::size_t index, float value) noexcept override {
        if (index < parameter_count()) effect_.set_parameter_value(static_cast<int>(index), value);
    }

    void process(const godot::AudioFrame* source, godot::AudioFrame* destination,
                 std::int32_t frame_count) noexcept override {
        std::int32_t offset = 0;
        while (offset < frame_count) {
            const auto chunk = static_cast<std::size_t>(
                std::min<std::int32_t>(frame_count - offset, static_cast<std::int32_t>(kChunkFrames)));
            for (std::size_t frame = 0; frame < chunk; ++frame) {
                input_left_[frame] = source[offset + static_cast<std::int32_t>(frame)].left;
                input_right_[frame] = source[offset + static_cast<std::int32_t>(frame)].right;
            }
            float* inputs[] = {input_left_.data(), input_right_.data()};
            float* outputs[] = {output_left_.data(), output_right_.data()};
            effect_.process(inputs, outputs, static_cast<long>(chunk));
            for (std::size_t frame = 0; frame < chunk; ++frame) {
                destination[offset + static_cast<std::int32_t>(frame)].left = output_left_[frame];
                destination[offset + static_cast<std::int32_t>(frame)].right = output_right_[frame];
            }
            offset += static_cast<std::int32_t>(chunk);
        }
    }

private:
    Effect effect_;
    std::array<float, kChunkFrames> input_left_{};
    std::array<float, kChunkFrames> input_right_{};
    std::array<float, kChunkFrames> output_left_{};
    std::array<float, kChunkFrames> output_right_{};
};

using ProcessorFactory = std::unique_ptr<Processor> (*)(float sample_rate);

template <typename Effect>
std::unique_ptr<Processor> make_processor(float sample_rate) {
    return std::make_unique<ProcessorModel<Effect>>(sample_rate);
}

class AirwindohhsAudioEffectInstance final : public godot::AudioEffectInstance {
    GDCLASS(AirwindohhsAudioEffectInstance, godot::AudioEffectInstance)

public:
    void configure(std::unique_ptr<Processor> processor,
                   std::shared_ptr<const ParameterState> parameters);
    void _process(const void* source_buffer, godot::AudioFrame* destination,
                  std::int32_t frame_count) override;
    bool _process_silence() const override;

protected:
    static void _bind_methods() {}

private:
    std::unique_ptr<Processor> processor_;
    std::shared_ptr<const ParameterState> parameters_;
};

class AirwindohhsAudioEffect : public godot::AudioEffect {
    GDCLASS(AirwindohhsAudioEffect, godot::AudioEffect)

public:
    godot::Ref<godot::AudioEffectInstance> _instantiate() override;

    godot::String get_effect_id() const;
    godot::String get_category() const;
    godot::String get_upstream_name() const;
    godot::String get_short_description() const;
    godot::String get_tags() const;
    godot::PackedStringArray get_parameter_ids() const;

protected:
    static void _bind_methods();
    bool _set(const godot::StringName& name, const godot::Variant& value);
    bool _get(const godot::StringName& name, godot::Variant& result) const;
    void _get_property_list(godot::List<godot::PropertyInfo>* properties) const;
    bool _property_can_revert(const godot::StringName& name) const;
    bool _property_get_revert(const godot::StringName& name, godot::Variant& result) const;

    template <typename Effect>
    void configure(std::string_view effect_id, std::string_view category,
                   std::string_view upstream_name, std::string_view short_description,
                   std::string_view tags) {
        static_assert(Effect::kNumParameters <= static_cast<int>(ParameterState::kCapacity));
        // Some Airwindows effects embed multi-megabyte delay lines. Constructing a
        // metadata probe by value can exhaust the 1 MiB iOS main-thread stack before
        // the effect instance itself is ever created.
        const auto probe = std::make_unique<Effect>();
        effect_id_ = to_godot(effect_id);
        category_ = to_godot(category);
        upstream_name_ = to_godot(upstream_name);
        short_description_ = to_godot(short_description);
        tags_ = to_godot(tags);
        factory_ = &make_processor<Effect>;
        parameters_ = std::make_shared<ParameterState>();
        parameters_->initialize(static_cast<std::size_t>(Effect::kNumParameters));
        defaults_.reserve(Effect::kNumParameters);
        minimums_.assign(Effect::kNumParameters, 0.0f);
        maximums_.assign(Effect::kNumParameters, 1.0f);
        property_names_.reserve(Effect::kNumParameters);
        parameter_ids_.reserve(Effect::kNumParameters);
        for (int index = 0; index < Effect::kNumParameters; ++index) {
            const float value = static_cast<float>(probe->get_parameter_default(index));
            defaults_.push_back(value);
            parameters_->store(static_cast<std::size_t>(index), value);
            const auto parameter_name = to_godot(probe->get_parameter_name(index));
            const auto property_slug = slugify(parameter_name, index);
            property_names_.emplace_back("parameters/" + property_slug);
            parameter_ids_.push_back(effect_id_ + "." + property_slug);
        }
    }

    void set_parameter_range(int index, float minimum, float maximum) {
        if (index < 0 || static_cast<std::size_t>(index) >= minimums_.size()) return;
        minimums_[index] = minimum;
        maximums_[index] = maximum;
    }

private:
    static godot::String to_godot(std::string_view text);
    static godot::String slugify(const godot::String& text, int fallback_index);
    int find_parameter(const godot::StringName& name) const;

    godot::String effect_id_;
    godot::String category_;
    godot::String upstream_name_;
    godot::String short_description_;
    godot::String tags_;
    ProcessorFactory factory_ = nullptr;
    std::shared_ptr<ParameterState> parameters_;
    std::vector<float> defaults_;
    std::vector<float> minimums_;
    std::vector<float> maximums_;
    std::vector<godot::StringName> property_names_;
    std::vector<godot::String> parameter_ids_;
};

} // namespace airwindohhs_godot
