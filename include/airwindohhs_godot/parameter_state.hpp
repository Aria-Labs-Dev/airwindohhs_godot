#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <initializer_list>

namespace airwindohhs_godot {

class ParameterState {
public:
    static constexpr std::size_t kCapacity = 16;
    static_assert(std::atomic<float>::is_always_lock_free,
                  "Audio-thread parameter snapshots require lock-free float atomics");

    void initialize(std::size_t count) noexcept {
        count_ = count <= kCapacity ? count : kCapacity;
        for (auto& value : values_) value.store(0.0f, std::memory_order_relaxed);
    }

    void initialize(std::size_t count, std::initializer_list<float> defaults) noexcept {
        initialize(count);
        std::size_t index = 0;
        for (float value : defaults) {
            if (index >= count_) break;
            store(index++, value);
        }
    }

    std::size_t count() const noexcept { return count_; }

    void store(std::size_t index, float value) noexcept {
        if (index < count_) values_[index].store(value, std::memory_order_relaxed);
    }

    float load(std::size_t index) const noexcept {
        return index < count_ ? values_[index].load(std::memory_order_relaxed) : 0.0f;
    }

private:
    std::array<std::atomic<float>, kCapacity> values_{};
    std::size_t count_ = 0;
};

} // namespace airwindohhs_godot
