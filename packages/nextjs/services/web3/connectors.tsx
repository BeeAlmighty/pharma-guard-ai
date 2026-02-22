import { argent, braavos, injected, InjectedConnector } from "@starknet-react/core";
import { getTargetNetworks } from "~~/utils/scaffold-stark";
import { BurnerConnector } from "@scaffold-stark/stark-burner";
import scaffoldConfig from "~~/scaffold.config";
import { LAST_CONNECTED_TIME_LOCALSTORAGE_KEY } from "~~/utils/Constants";
import { KeplrConnector } from "./keplr";

const targetNetworks = getTargetNetworks();

// workaround helper function to properly disconnect with removing local storage (prevent autoconnect infinite loop)
function withDisconnectWrapper(connector: InjectedConnector) {
  const connectorDisconnect = connector.disconnect;
  const _disconnect = (): Promise<void> => {
    localStorage.removeItem("lastUsedConnector");
    localStorage.removeItem(LAST_CONNECTED_TIME_LOCALSTORAGE_KEY);
    return connectorDisconnect();
  };
  connector.disconnect = _disconnect.bind(connector);
  return connector;
}

// MetaMask Starknet Snap connector
// Discovery via injected({id: 'metamask'}) is the standard way in v5.0.3+
const metamaskSnapConnector = injected({
  id: "metamask",
});

function getConnectors() {
  const { targetNetworks } = scaffoldConfig;

  const connectors = [argent(), braavos(), metamaskSnapConnector];
  const isDevnet = targetNetworks.some(
    (network) => (network.network as string) === "devnet",
  );

  if (!isDevnet) {
    connectors.push(new KeplrConnector());
  } else {
    const burnerConnector = new BurnerConnector();
    // burnerConnector's should be initialized with dynamic network instead of hardcoded devnet to support mainnetFork
    burnerConnector.chain = targetNetworks[0];
    connectors.push(burnerConnector as unknown as InjectedConnector);
  }

  return connectors.sort(() => Math.random() - 0.5).map(withDisconnectWrapper);
}

export const connectors = getConnectors();

export const appChains = targetNetworks;


