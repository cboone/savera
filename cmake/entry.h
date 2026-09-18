#pragma once

extern "C" {
bool savera_clap_init(const char *plugin_path);
void savera_clap_deinit(void);
const void *savera_clap_get_factory(const char *factory_id);
}
