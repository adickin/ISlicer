// iOS stub for GCode/Thumbnails.cpp — JPEG thumbnail encoding disabled.
// Thumbnails in gcode are optional visual previews; slicing works without them.
#include "Thumbnails.hpp"

#include <boost/algorithm/string/case_conv.hpp>
#include <boost/log/trivial.hpp>
#include <string>

#include "libslic3r/Config.hpp"
#include "libslic3r/GCode/ThumbnailData.hpp"
#include "libslic3r/PrintConfig.hpp"

namespace Slic3r::GCodeThumbnails {

using namespace std::literals;

// Return empty (null) buffer — no thumbnail encoding on iOS.
std::unique_ptr<CompressedImageBuffer> compress_thumbnail(const ThumbnailData & /*data*/, GCodeThumbnailsFormat /*format*/)
{
    struct EmptyBuffer : CompressedImageBuffer {
        ~EmptyBuffer() override = default;
        std::string_view tag() const override { return "thumbnail"sv; }
    };
    return std::make_unique<EmptyBuffer>();
}

std::pair<GCodeThumbnailDefinitionsList, ThumbnailErrors>
make_and_check_thumbnail_list(const std::string & /*thumbnails_string*/, const std::string_view /*def_ext*/)
{
    return {{}, ThumbnailErrors{}};
}

std::pair<GCodeThumbnailDefinitionsList, ThumbnailErrors>
make_and_check_thumbnail_list(const ConfigBase & /*config*/)
{
    return {{}, ThumbnailErrors{}};
}

std::string get_error_string(const ThumbnailErrors & /*errors*/)
{
    return {};
}

} // namespace Slic3r::GCodeThumbnails
