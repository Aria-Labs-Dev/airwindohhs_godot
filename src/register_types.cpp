#include "register_types.hpp"

#include "effects.hpp"
#include <airwindohhs_godot/audio_effect.hpp>
#include <godot_cpp/godot.hpp>

void initialize_airwindohhs_godot(godot::ModuleInitializationLevel level) {
    if (level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(airwindohhs_godot::AirwindohhsAudioEffectInstance);
    GDREGISTER_ABSTRACT_CLASS(airwindohhs_godot::AirwindohhsAudioEffect);
    airwindohhs_godot::register_generated_effects();
}

void uninitialize_airwindohhs_godot(godot::ModuleInitializationLevel level) {
    if (level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) return;
}

extern "C" {
GDExtensionBool GDE_EXPORT airwindohhs_godot_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization* initialization) {
    godot::GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize_airwindohhs_godot);
    init.register_terminator(uninitialize_airwindohhs_godot);
    init.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
