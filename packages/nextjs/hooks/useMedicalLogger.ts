import { useState } from 'react';
import { hash } from 'starknet';
import { useScaffoldWriteContract } from './scaffold-stark/useScaffoldWriteContract';
import { useScaffoldReadContract } from './scaffold-stark/useScaffoldReadContract';

// ─── Commitment helper ───────────────────────────────────────────────────────
/**
 * Derives a stable felt252 commitment from a sorted list of drug names.
 * The same drug set always produces the same commitment, enabling idempotent
 * on-chain lookup via MedicalLogger.get_log.
 */
export const drugListToCommitment = (drugs: string[]): string => {
    if (drugs.length === 0) return '0x0';
    const key = drugs
        .map(d => d.toLowerCase().trim())
        .sort()
        .join('+');
    // starknetKeccak returns a BigInt truncated to 251 bits (fits felt252)
    return hash.starknetKeccak(key).toString();
};

// ─── Risk level helpers ───────────────────────────────────────────────────────
/** Maps an AI severity string to the on-chain risk_level u8 value. */
export const severityToRiskLevel = (severity: string): number => {
    if (severity === 'High') return 3;
    if (severity === 'Moderate') return 2;
    return 1;
};

/** Derives the highest risk level from an array of interactions. */
export const maxRiskFromInteractions = (
    interactions: Array<{ severity: string }> | null,
): number => {
    if (!interactions || interactions.length === 0) return 1;
    return Math.max(...interactions.map(i => severityToRiskLevel(i.severity)));
};

// ─── Hook ─────────────────────────────────────────────────────────────────────
/**
 * useMedicalLogger
 *
 * Wraps the MedicalLogger contract's three write functions and one read
 * function into a single, easy-to-use hook.
 *
 * Usage:
 *   const { logSafetyCheck, blockEntry, overrideWarning, txHash, isPending } =
 *     useMedicalLogger();
 */
export const useMedicalLogger = (commitment: string) => {
    const [txHash, setTxHash] = useState<string | null>(null);
    const [isPending, setIsPending] = useState(false);
    const [txError, setTxError] = useState<string | null>(null);

    // ── log_safety_check ──────────────────────────────────────────────────────
    const { sendAsync: sendLog } = useScaffoldWriteContract({
        contractName: 'MedicalLogger',
        functionName: 'log_safety_check',
        args: [BigInt(commitment || '0'), 1],
    });

    // ── confirm_block ─────────────────────────────────────────────────────────
    const { sendAsync: sendBlock } = useScaffoldWriteContract({
        contractName: 'MedicalLogger',
        functionName: 'confirm_block',
        args: [BigInt(commitment || '0')],
    });

    // ── override_warning ──────────────────────────────────────────────────────
    const { sendAsync: sendOverride } = useScaffoldWriteContract({
        contractName: 'MedicalLogger',
        functionName: 'override_warning',
        args: [BigInt(commitment || '0'), BigInt('0x0')],
    });

    // ── get_log (view) ────────────────────────────────────────────────────────
    const { data: logEntry, refetch: refetchLog } = useScaffoldReadContract({
        contractName: 'MedicalLogger',
        functionName: 'get_log',
        args: [BigInt(commitment || '0')],
        enabled: commitment !== '0x0',
    });

    // ── helpers ───────────────────────────────────────────────────────────────
    const withTx = async (fn: () => Promise<string | undefined>) => {
        setIsPending(true);
        setTxError(null);
        setTxHash(null);
        try {
            const result = await fn();
            if (result) setTxHash(result);
            await refetchLog();
            return result;
        } catch (e: any) {
            setTxError(e?.message ?? 'Transaction failed');
            throw e;
        } finally {
            setIsPending(false);
        }
    };

    const logSafetyCheck = (riskLevel: number) =>
        withTx(() =>
            sendLog({ args: [BigInt(commitment), riskLevel] }),
        );

    const blockEntry = () =>
        withTx(() => sendBlock({ args: [BigInt(commitment)] }));

    const overrideWarning = (reason: string) => {
        const reasonHash = reason
            ? hash.starknetKeccak(reason).toString()
            : '0x1';
        return withTx(() =>
            sendOverride({
                args: [BigInt(commitment), BigInt(reasonHash)],
            }),
        );
    };

    return {
        logSafetyCheck,
        blockEntry,
        overrideWarning,
        logEntry,
        txHash,
        isPending,
        txError,
    };
};
