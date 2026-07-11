#include <airwindohhs_godot/audio_effect.hpp>

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/property_info.hpp>

namespace airwindohhs_godot {

void AirwindohhsAudioEffectInstance::configure(
    std::unique_ptr<Processor> processor, std::shared_ptr<const ParameterState> parameters) {
    processor_ = std::move(processor);
    parameters_ = std::move(parameters);
}

void AirwindohhsAudioEffectInstance::_process(const void* source_buffer,
                                              godot::AudioFrame* destination,
                                              std::int32_t frame_count) {
    const auto* source = static_cast<const godot::AudioFrame*>(source_buffer);
    if (!processor_ || !parameters_ || !source || !destination || frame_count <= 0) return;
    const auto count = std::min(processor_->parameter_count(), parameters_->count());
    for (std::size_t index = 0; index < count; ++index)
        processor_->set_parameter(index, parameters_->load(index));
    processor_->process(source, destination, frame_count);
}

bool AirwindohhsAudioEffectInstance::_process_silence() const { return true; }

godot::Ref<godot::AudioEffectInstance> AirwindohhsAudioEffect::_instantiate() {
    godot::Ref<AirwindohhsAudioEffectInstance> instance;
    instance.instantiate();
    const auto* server = godot::AudioServer::get_singleton();
    const float sample_rate = server ? server->get_mix_rate() : 44100.0f;
    if (factory_ && parameters_) instance->configure(factory_(sample_rate), parameters_);
    return instance;
}

godot::String AirwindohhsAudioEffect::get_effect_id() const { return effect_id_; }
godot::String AirwindohhsAudioEffect::get_category() const { return category_; }
godot::String AirwindohhsAudioEffect::get_upstream_name() const { return upstream_name_; }
godot::String AirwindohhsAudioEffect::get_short_description() const { return short_description_; }
godot::String AirwindohhsAudioEffect::get_tags() const { return tags_; }

godot::PackedStringArray AirwindohhsAudioEffect::get_parameter_ids() const {
    godot::PackedStringArray result;
    for (const auto& id : parameter_ids_) result.push_back(id);
    return result;
}

void AirwindohhsAudioEffect::_bind_methods() {
    godot::ClassDB::bind_method(godot::D_METHOD("get_effect_id"), &AirwindohhsAudioEffect::get_effect_id);
    godot::ClassDB::bind_method(godot::D_METHOD("get_category"), &AirwindohhsAudioEffect::get_category);
    godot::ClassDB::bind_method(godot::D_METHOD("get_upstream_name"), &AirwindohhsAudioEffect::get_upstream_name);
    godot::ClassDB::bind_method(godot::D_METHOD("get_short_description"), &AirwindohhsAudioEffect::get_short_description);
    godot::ClassDB::bind_method(godot::D_METHOD("get_tags"), &AirwindohhsAudioEffect::get_tags);
    godot::ClassDB::bind_method(godot::D_METHOD("get_parameter_ids"), &AirwindohhsAudioEffect::get_parameter_ids);
}

bool AirwindohhsAudioEffect::_set(const godot::StringName& name, const godot::Variant& value) {
    const int index = find_parameter(name);
    if (index < 0 || value.get_type() != godot::Variant::FLOAT) return false;
    parameters_->store(static_cast<std::size_t>(index),
                       std::clamp(static_cast<float>(value), minimums_[index], maximums_[index]));
    emit_changed();
    return true;
}

bool AirwindohhsAudioEffect::_get(const godot::StringName& name, godot::Variant& result) const {
    const int index = find_parameter(name);
    if (index < 0) return false;
    result = parameters_->load(static_cast<std::size_t>(index));
    return true;
}

void AirwindohhsAudioEffect::_get_property_list(
    godot::List<godot::PropertyInfo>* properties) const {
    for (std::size_t index = 0; index < property_names_.size(); ++index) {
        const auto hint = godot::String::num(minimums_[index]) + "," +
                          godot::String::num(maximums_[index]) + ",0.0001";
        properties->push_back(godot::PropertyInfo(godot::Variant::FLOAT, property_names_[index],
            godot::PROPERTY_HINT_RANGE, hint));
    }
}

bool AirwindohhsAudioEffect::_property_can_revert(const godot::StringName& name) const {
    const int index = find_parameter(name);
    return index >= 0 && parameters_->load(static_cast<std::size_t>(index)) != defaults_[index];
}

bool AirwindohhsAudioEffect::_property_get_revert(const godot::StringName& name,
                                                  godot::Variant& result) const {
    const int index = find_parameter(name);
    if (index < 0) return false;
    result = defaults_[index];
    return true;
}

godot::String AirwindohhsAudioEffect::to_godot(std::string_view text) {
    return godot::String::utf8(text.data(), static_cast<std::int64_t>(text.size()));
}

godot::String AirwindohhsAudioEffect::slugify(const godot::String& text, int fallback_index) {
    godot::String result;
    bool previous_separator = false;
    const godot::String lower = text.to_lower();
    for (std::int64_t index = 0; index < lower.length(); ++index) {
        const char32_t character = lower[index];
        const bool alphanumeric = (character >= U'a' && character <= U'z') ||
                                  (character >= U'0' && character <= U'9');
        if (alphanumeric) {
            result += character;
            previous_separator = false;
        } else if (!result.is_empty() && !previous_separator) {
            result += U'_';
            previous_separator = true;
        }
    }
    while (result.ends_with("_")) result = result.left(result.length() - 1);
    return result.is_empty() ? "parameter_" + godot::String::num_int64(fallback_index) : result;
}

int AirwindohhsAudioEffect::find_parameter(const godot::StringName& name) const {
    for (std::size_t index = 0; index < property_names_.size(); ++index)
        if (property_names_[index] == name) return static_cast<int>(index);
    return -1;
}

} // namespace airwindohhs_godot
