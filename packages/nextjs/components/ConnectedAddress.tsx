// "use client";
// import { useAccount } from "~~/hooks/useAccount";
// import { Address } from "./scaffold-stark";
// import { useScaffoldStarkProfile } from "~~/hooks/scaffold-stark/useScaffoldStarkProfile";

// export const ConnectedAddress = () => {
//   const connectedAddress = useAccount();

//   const { data: fetchedProfile, isLoading } = useScaffoldStarkProfile(
//     connectedAddress.address,
//   );

//   return (
//     <div className="flex justify-center items-center space-x-2">
//       <p className="my-2 font-medium text-[#00A3FF]">Connected Address:</p>
//       <Address
//         address={connectedAddress.address}
//         profile={fetchedProfile}
//         isLoading={isLoading}
//       />
//     </div>
//   );
// };
"use client";
import { useAccount } from "~~/hooks/useAccount";
import { Address } from "./scaffold-stark";
import { useScaffoldStarkProfile } from "~~/hooks/scaffold-stark/useScaffoldStarkProfile";

export const ConnectedAddress = () => {
  const { address } = useAccount();

  const { data: fetchedProfile, isLoading } = useScaffoldStarkProfile(
    address,
  );

  if (!address) return null;

  return (
    <div className="flex justify-center items-center space-x-2">
      <p className="my-2 font-medium text-[#00A3FF]">Connected Address:</p>
      <Address
        address={address}
        // If fetchedProfile is null/undefined (like during a 400 error), 
        // it safely falls back to just showing the address string.
        profile={fetchedProfile || undefined}
        isLoading={isLoading}
      />
    </div>
  );
};