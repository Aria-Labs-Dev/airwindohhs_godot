#include <airwindohhs_godot/parameter_state.hpp>

#include <cmath>
#include <cstdlib>
#include <iostream>

int main() {
    airwindohhs_godot::ParameterState state;
    state.initialize(3, {0.0f, 0.5f, 1.0f});
    if (state.count() != 3 || std::abs(state.load(1) - 0.5f) > 1.0e-6f) {
        std::cerr << "parameter defaults were not initialized\n";
        return EXIT_FAILURE;
    }
    state.store(1, 0.75f);
    if (std::abs(state.load(1) - 0.75f) > 1.0e-6f) {
        std::cerr << "parameter snapshot handoff failed\n";
        return EXIT_FAILURE;
    }
    state.store(99, 1.0f);
    if (state.load(99) != 0.0f) {
        std::cerr << "out-of-range parameter access was not bounded\n";
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
