import { Connector, useConnect } from "@starknet-react/core";
import { useRef, useState } from "react";
import { useLocalStorage } from "usehooks-ts";
import { BurnerConnector, burnerAccounts } from "@scaffold-stark/stark-burner";
import { useTheme } from "next-themes";
import { BlockieAvatar } from "../BlockieAvatar";
import GenericModal from "./GenericModal";
import Wallet from "~~/components/scaffold-stark/CustomConnectButton/Wallet";
import { LAST_CONNECTED_TIME_LOCALSTORAGE_KEY } from "~~/utils/Constants";
import { useTargetNetwork } from "~~/hooks/scaffold-stark/useTargetNetwork";

const loader = ({ src }: { src: string }) => src;

const ConnectModal = () => {
  const modalRef = useRef<HTMLInputElement>(null);
  const [isBurnerWallet, setIsBurnerWallet] = useState(false);
  const { resolvedTheme } = useTheme();
  const isDarkMode = resolvedTheme === "dark";
  const { connectors, connect } = useConnect();
  const [, setLastConnector] = useLocalStorage<{ id: string; ix?: number }>(
    "lastUsedConnector",
    { id: "" },
  );
  const [, setLastConnectionTime] = useLocalStorage<number>(
    LAST_CONNECTED_TIME_LOCALSTORAGE_KEY,
    0,
  );
  const [, setWasDisconnectedManually] = useLocalStorage<boolean>(
    "wasDisconnectedManually",
    false,
  );
  const { targetNetwork } = useTargetNetwork();
  const [showOtherOptions, setShowOtherOptions] = useState(false);

  // Identify devnet by network name
  const isDevnet = targetNetwork.network === "devnet";

  // Separate MetaMask Snap from the rest for featured placement
  const metamaskConnector = connectors.find((c) => c.id === "metamask");
  const isMetaMaskInstalled =
    typeof window !== "undefined" && !!(window as any).ethereum;

  // Split connectors into main and other options for devnet
  let mainConnectors = connectors;
  let otherConnectors: typeof connectors = [];
  if (isDevnet) {
    mainConnectors = connectors.filter((c) => c.id === "burner-wallet");
    otherConnectors = connectors.filter((c) => c.id !== "burner-wallet");
  }

  // Non-metamask main connectors for the standard list
  const standardMainConnectors = mainConnectors.filter(
    (c) => c.id !== "metamask",
  );

  const handleCloseModal = () => {
    if (modalRef.current) modalRef.current.checked = false;
  };

  function handleConnectWallet(
    e: React.MouseEvent<HTMLButtonElement>,
    connector: Connector,
  ) {
    if (connector.id === "burner-wallet") {
      setIsBurnerWallet(true);
      return;
    }
    setWasDisconnectedManually(false);
    connect({ connector });
    setLastConnector({ id: connector.id });
    setLastConnectionTime(Date.now());
    handleCloseModal();
  }

  function handleConnectBurner(
    e: React.MouseEvent<HTMLButtonElement>,
    ix: number,
  ) {
    const connector = connectors.find((it) => it.id == "burner-wallet");
    if (connector && connector instanceof BurnerConnector) {
      connector.burnerAccount = burnerAccounts[ix];
      setWasDisconnectedManually(false);
      connect({ connector });
      setLastConnector({ id: connector.id, ix });
      setLastConnectionTime(Date.now());
      handleCloseModal();
    }
  }

  return (
    <div>
      <label
        htmlFor="connect-modal"
        className="rounded-[18px] btn-sm  font-bold px-8 bg-btn-wallet py-3 cursor-pointer"
      >
        <span>Connect</span>
      </label>
      <input
        ref={modalRef}
        type="checkbox"
        id="connect-modal"
        className="modal-toggle"
      />
      <GenericModal modalId="connect-modal">
        <>
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-bold">
              {isBurnerWallet
                ? "Choose account"
                : showOtherOptions
                  ? "Other Wallet Options"
                  : "Connect a Wallet"}
            </h3>
            <label
              onClick={() => {
                setIsBurnerWallet(false);
                setShowOtherOptions(false);
              }}
              htmlFor="connect-modal"
              className="btn btn-ghost btn-sm btn-circle cursor-pointer"
            >
              ✕
            </label>
          </div>
          <div className="flex flex-col flex-1 lg:grid">
            <div className="flex flex-col gap-4 w-full px-8 py-10">
              {!isBurnerWallet ? (
                !showOtherOptions ? (
                  <>
                    {/* ── MetaMask Starknet Snap — featured ──────────────── */}
                    {!isDevnet && metamaskConnector && (
                      <>
                        <div className="flex flex-col gap-1">
                          <p className="text-[10px] uppercase tracking-widest text-slate-500 font-bold px-1">
                            MetaMask
                          </p>
                          <div
                            className={`border rounded-[6px] p-0.5 ${isDarkMode
                              ? "border-orange-500/40 bg-orange-500/5"
                              : "border-orange-400/50 bg-orange-50"
                              }`}
                          >
                            <div className="relative">
                              <button
                                className={`flex gap-4 items-center text-neutral w-full rounded-[4px] p-3 transition-all ${isDarkMode
                                  ? "hover:bg-orange-500/10"
                                  : "hover:bg-orange-100/50"
                                  }`}
                                onClick={(e) =>
                                  handleConnectWallet(e, metamaskConnector)
                                }
                              >
                                <div className="h-6 w-6">
                                  <img
                                    src="https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg"
                                    alt="MetaMask"
                                    className="h-full w-full object-contain"
                                  />
                                </div>
                                <span className="font-bold">MetaMask</span>
                              </button>
                              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-bold px-1.5 py-0.5 rounded bg-orange-500/20 text-orange-400 border border-orange-500/30">
                                Starknet Snap
                              </span>
                            </div>
                            {!isMetaMaskInstalled && (
                              <p className="text-[11px] text-slate-500 px-3 pb-2 pt-1">
                                MetaMask not detected —{" "}
                                <a
                                  href="https://metamask.io/download"
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="text-orange-400 underline hover:text-orange-300"
                                >
                                  install it
                                </a>{" "}
                                first, then connect.
                              </p>
                            )}
                          </div>
                        </div>

                        {/* Divider */}
                        <div className="flex items-center gap-3 my-1">
                          <div className="flex-1 h-px bg-slate-700/50" />
                          <span className="text-[10px] uppercase tracking-widest text-slate-600">
                            or
                          </span>
                          <div className="flex-1 h-px bg-slate-700/50" />
                        </div>
                      </>
                    )}

                    {/* ── Standard wallets ───────────────────────────────── */}
                    {standardMainConnectors.map((connector, index) => (
                      <Wallet
                        key={connector.id || index}
                        connector={connector}
                        loader={loader}
                        handleConnectWallet={handleConnectWallet}
                      />
                    ))}

                    {isDevnet && otherConnectors.length > 0 && (
                      <button
                        className="btn btn-ghost rounded-md mt-4 font-normal text-base"
                        onClick={() => setShowOtherOptions(true)}
                      >
                        Other Options
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    {otherConnectors.map((connector, index) => (
                      <Wallet
                        key={connector.id || index}
                        connector={connector}
                        loader={loader}
                        handleConnectWallet={handleConnectWallet}
                      />
                    ))}
                    <button
                      className="btn btn-ghost font-normal text-base mt-4 rounded-md"
                      onClick={() => setShowOtherOptions(false)}
                    >
                      Back
                    </button>
                  </>
                )
              ) : (
                <div className="flex flex-col pb-[20px] justify-end gap-3">
                  <div className="h-[300px] overflow-y-auto flex w-full flex-col gap-2">
                    {burnerAccounts.map((burnerAcc, ix) => (
                      <div
                        key={burnerAcc.publicKey}
                        className="w-full flex flex-col"
                      >
                        <button
                          className={`hover:bg-gradient-modal border rounded-md text-neutral py-[8px] pl-[10px] pr-16 flex items-center gap-4 ${isDarkMode ? "border-[#385183]" : ""}`}
                          onClick={(e) => handleConnectBurner(e, ix)}
                        >
                          <BlockieAvatar
                            address={burnerAcc.accountAddress}
                            size={35}
                          />
                          {`${burnerAcc.accountAddress.slice(0, 6)}...${burnerAcc.accountAddress.slice(-4)}`}
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </>
      </GenericModal>
    </div>
  );
};

export default ConnectModal;


