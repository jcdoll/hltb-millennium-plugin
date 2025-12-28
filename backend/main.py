import Millennium
import PluginUtils  # type: ignore

logger = PluginUtils.Logger()


class Plugin:
    def _front_end_loaded(self):
        logger.log("Frontend loaded")

    def _load(self):
        logger.log(f"bootstrapping HLTB plugin, millennium {Millennium.version()}")
        Millennium.ready()

    def _unload(self):
        logger.log("unloading")
