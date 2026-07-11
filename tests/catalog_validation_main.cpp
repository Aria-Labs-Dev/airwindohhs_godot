#include "catalog_validation.hpp"

#include <cstdlib>
#include <iostream>

namespace airwindohhs_godot::validation {
void validate_catalog_00(Report&); void validate_catalog_01(Report&);
void validate_catalog_02(Report&); void validate_catalog_03(Report&);
void validate_catalog_04(Report&); void validate_catalog_05(Report&);
void validate_catalog_06(Report&); void validate_catalog_07(Report&);
void validate_catalog_08(Report&); void validate_catalog_09(Report&);
void validate_catalog_10(Report&); void validate_catalog_11(Report&);
void validate_catalog_12(Report&); void validate_catalog_13(Report&);
void validate_catalog_14(Report&); void validate_catalog_15(Report&);
} // namespace airwindohhs_godot::validation

int main() {
    using namespace airwindohhs_godot::validation;
    Report report;
    validate_catalog_00(report); validate_catalog_01(report);
    validate_catalog_02(report); validate_catalog_03(report);
    validate_catalog_04(report); validate_catalog_05(report);
    validate_catalog_06(report); validate_catalog_07(report);
    validate_catalog_08(report); validate_catalog_09(report);
    validate_catalog_10(report); validate_catalog_11(report);
    validate_catalog_12(report); validate_catalog_13(report);
    validate_catalog_14(report); validate_catalog_15(report);
    for (const auto& failure : report.failures) std::cerr << failure << '\n';
    std::cout << "effects=" << report.effects << " renders=" << report.renders
              << " failures=" << report.failures.size() << '\n';
    return report.effects == 495u && report.failures.empty() ? EXIT_SUCCESS : EXIT_FAILURE;
}
