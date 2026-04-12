// iOS stub for ArrangeHelper.cpp.
// Sequential arrangement (Z3-based) is not available on iOS.
// These stub implementations ensure the linker is satisfied.
// None of these functions are reachable in basic FDM slicing mode.
#include "ArrangeHelper.hpp"
#include "libslic3r/Model.hpp"
#include <optional>
#include <string>

namespace Slic3r {

void arrange_model_sequential(Model& /*model*/, const ConfigBase& /*config*/)
{
    // No-op on iOS — sequential arrangement requires Z3 theorem prover.
}

std::optional<std::pair<std::string, std::string>>
check_seq_conflict(const Model& /*model*/, const ConfigBase& /*config*/)
{
    // Never called in basic FDM mode (complete_objects == false).
    return std::nullopt;
}

SeqArrange::SeqArrange(const Model& /*model*/, const ConfigBase& /*config*/, bool /*current_bed_only*/)
    : m_printer_geometry{}
    , m_solver_configuration{}
    , m_objects{}
    , m_selected_bed(-1)
    , m_plates{}
{}

void SeqArrange::process_seq_arrange(std::function<void(int)> /*progress_fn*/) {}

void SeqArrange::apply_seq_arrange(Model& /*model*/) const {}

} // namespace Slic3r
