'use client';

import { useState } from 'react';
import { useAccount } from '@starknet-react/core';
import {
    ShieldCheck,
    ShieldAlert,
    Star,
    Zap,
    Lock,
    AlertTriangle,
    CheckCircle,
    Loader2,
} from 'lucide-react';
import { useScaffoldReadContract } from '~~/hooks/scaffold-stark/useScaffoldReadContract';
import { useMedicalLogger } from '~~/hooks/useMedicalLogger';
import type { Interaction } from '~~/hooks/useDrugInteractions';

interface Props {
    commitment: string;
    interactions: Interaction[] | null;
    maxRiskLevel: number;
}

// ─── Sub-components ────────────────────────────────────────────────────────────

function StatusBadge({ active, label }: { active: boolean; label: string }) {
    return (
        <div
            className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-bold border ${active
                ? 'bg-emerald-500/15 border-emerald-500/30 text-emerald-400'
                : 'bg-slate-800 border-slate-700 text-slate-500'
                }`}
        >
            {active ? (
                <ShieldCheck className="w-3.5 h-3.5" />
            ) : (
                <ShieldAlert className="w-3.5 h-3.5" />
            )}
            {label}
        </div>
    );
}

function TxToast({
    hash,
    error,
}: {
    hash: string | null;
    error: string | null;
}) {
    if (!hash && !error) return null;
    return (
        <div
            className={`mt-3 p-3 rounded-xl text-xs font-mono border ${error
                ? 'bg-red-500/10 border-red-500/20 text-red-400'
                : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
                }`}
        >
            {error ? (
                <span>⚠ {error.slice(0, 80)}</span>
            ) : (
                <span>✔ Tx: {hash?.slice(0, 12)}…{hash?.slice(-6)}</span>
            )}
        </div>
    );
}

// ─── Main Component ────────────────────────────────────────────────────────────

export default function PharmacistPanel({
    commitment,
    interactions,
    maxRiskLevel,
}: Props) {
    const { address, status } = useAccount();
    const [overrideReason, setOverrideReason] = useState('');
    const [showOverrideInput, setShowOverrideInput] = useState(false);

    // ── Read: pharmacist status ──────────────────────────────────────────────
    const { data: isPharmacist } = useScaffoldReadContract({
        contractName: 'PharmacistRegistry',
        functionName: 'is_pharmacist',
        args: [address!],
        enabled: !!address,
    });

    // ── Read: reputation score ───────────────────────────────────────────────
    const { data: reputationScore } = useScaffoldReadContract({
        contractName: 'ReputationSBT',
        functionName: 'reputation_score',
        args: [address!],
        enabled: !!address,
    });

    // ── Write hooks ──────────────────────────────────────────────────────────
    const { logSafetyCheck, blockEntry, overrideWarning, txHash, isPending, txError } =
        useMedicalLogger(commitment);

    const hasInteractions = !!interactions && interactions.length > 0;
    const isHighRisk = maxRiskLevel >= 3;
    const isMediumRisk = maxRiskLevel === 2;
    const connected = status === 'connected';

    // ─────────────────────────────────────────────────────────────────────────
    return (
        <div className="bg-slate-900/60 border border-white/5 rounded-2xl p-5 backdrop-blur-xl flex flex-col gap-5">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full bg-indigo-600/20 border border-indigo-500/30 flex items-center justify-center">
                        <Zap className="w-4 h-4 text-indigo-400" />
                    </div>
                    <h2 className="text-sm font-bold text-white">On-Chain Audit</h2>
                </div>
                <StatusBadge
                    active={!!isPharmacist}
                    label={isPharmacist ? 'Pharmacist' : 'Unregistered'}
                />
            </div>

            {/* Wallet not connected */}
            {!connected && (
                <div className="flex items-center gap-2 p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl text-amber-400 text-xs">
                    <AlertTriangle className="w-4 h-4 shrink-0" />
                    Connect wallet to enable audit logging
                </div>
            )}

            {/* Not a pharmacist warning */}
            {connected && !isPharmacist && (
                <div className="flex items-center gap-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-xs">
                    <ShieldAlert className="w-4 h-4 shrink-0" />
                    Your wallet is not registered as a pharmacist. Ask the admin to call{' '}
                    <code className="font-mono bg-slate-800 px-1 rounded">add_pharmacist</code>.
                </div>
            )}

            {/* Reputation score */}
            {connected && (
                <div className="flex items-center justify-between p-3 bg-slate-800/40 border border-white/5 rounded-xl">
                    <div className="flex items-center gap-2 text-slate-400 text-xs font-bold uppercase tracking-wider">
                        <Star className="w-3.5 h-3.5 text-amber-400" />
                        Reputation Score
                    </div>
                    <span className="text-2xl font-bold text-amber-400">
                        {reputationScore !== undefined
                            ? reputationScore.toString()
                            : '—'}
                    </span>
                </div>
            )}

            {/* Commitment preview */}
            {hasInteractions && (
                <div className="p-3 bg-slate-950/50 rounded-xl border border-white/5">
                    <p className="text-[10px] uppercase tracking-wider text-slate-500 font-bold mb-1">
                        Commitment Hash
                    </p>
                    <p className="font-mono text-xs text-slate-400 truncate">
                        {commitment.slice(0, 20)}…{commitment.slice(-8)}
                    </p>
                </div>
            )}

            {/* Action buttons — only shown after AI analysis and wallet connected */}
            {hasInteractions && connected && isPharmacist && (
                <div className="flex flex-col gap-3">
                    {/* Log Safety Check */}
                    <button
                        onClick={() => logSafetyCheck(maxRiskLevel)}
                        disabled={isPending}
                        className="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:grayscale text-white font-bold text-sm transition-all"
                    >
                        {isPending ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                            <CheckCircle className="w-4 h-4" />
                        )}
                        Log Safety Check
                    </button>

                    {/* Confirm Block (high risk only) */}
                    {isHighRisk && (
                        <button
                            onClick={() => blockEntry()}
                            disabled={isPending}
                            className="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-red-600/80 hover:bg-red-500 disabled:opacity-50 disabled:grayscale text-white font-bold text-sm transition-all border border-red-500/30"
                        >
                            {isPending ? (
                                <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                                <ShieldAlert className="w-4 h-4" />
                            )}
                            Confirm Block &amp; Earn Badge
                        </button>
                    )}

                    {/* Override Warning (medium risk — allow override with reason) */}
                    {isMediumRisk && !isHighRisk && (
                        <div className="flex flex-col gap-2">
                            {showOverrideInput ? (
                                <>
                                    <input
                                        type="text"
                                        value={overrideReason}
                                        onChange={e => setOverrideReason(e.target.value)}
                                        placeholder="Override reason (e.g. 'benefit outweighs risk')"
                                        className="w-full px-3 py-2 bg-slate-950/40 border border-slate-700 rounded-xl text-xs text-slate-200 outline-none focus:border-amber-500/50 placeholder:text-slate-600"
                                    />
                                    <button
                                        onClick={async () => {
                                            await overrideWarning(overrideReason);
                                            setShowOverrideInput(false);
                                            setOverrideReason('');
                                        }}
                                        disabled={isPending || !overrideReason.trim()}
                                        className="flex items-center justify-center gap-2 w-full py-2.5 rounded-xl bg-amber-600/80 hover:bg-amber-500 disabled:opacity-50 disabled:grayscale text-white font-bold text-sm transition-all"
                                    >
                                        {isPending ? (
                                            <Loader2 className="w-4 h-4 animate-spin" />
                                        ) : (
                                            <Lock className="w-4 h-4" />
                                        )}
                                        Submit Override
                                    </button>
                                </>
                            ) : (
                                <button
                                    onClick={() => setShowOverrideInput(true)}
                                    className="flex items-center justify-center gap-2 w-full py-3 rounded-xl bg-amber-600/30 hover:bg-amber-600/50 border border-amber-500/30 text-amber-300 font-bold text-sm transition-all"
                                >
                                    <Lock className="w-4 h-4" />
                                    Override Warning
                                </button>
                            )}
                        </div>
                    )}
                </div>
            )}

            {/* Tx status */}
            <TxToast hash={txHash} error={txError} />

            {/* No analysis yet */}
            {!hasInteractions && connected && isPharmacist && (
                <p className="text-xs text-slate-600 text-center">
                    Run AI evaluation to unlock on-chain logging
                </p>
            )}
        </div>
    );
}
