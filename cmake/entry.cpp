#include <clap/clap.h>

#include "entry.h"

extern "C" const CLAP_EXPORT struct clap_plugin_entry clap_entry = {
    CLAP_VERSION,
    savera_clap_init,
    savera_clap_deinit,
    savera_clap_get_factory,
};
