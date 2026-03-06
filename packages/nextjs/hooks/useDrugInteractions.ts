// packages/nextjs/hooks/useDrugInteractions.ts
import { useState, useMemo } from 'react';
import { drugListToCommitment, maxRiskFromInteractions } from './useMedicalLogger';

export interface Interaction {
	severity: string;
	drugs: string[];
	description: string;
	mechanism: string;
	alternatives: string;
	confidence?: number;
	citations?: string[];
}

export const useDrugInteractions = () => {
	const [drugList, setDrugList] = useState<string[]>([]);
	const [interactions, setInteractions] = useState<Interaction[] | null>(null);
	const [loading, setLoading] = useState<boolean>(false);

	const toTitleCase = (str: string) =>
		str.toLowerCase().replace(/\b\w/g, s => s.toUpperCase());

	const addDrug = (drugRaw: string) => {
		const drugClean = toTitleCase(drugRaw);
		if (!drugList.includes(drugClean)) {
			setDrugList(prev => [...prev, drugClean]);
			setInteractions(null);
		}
	};

	const removeDrug = (drug: string) => {
		setDrugList(prev => prev.filter(d => d !== drug));
		setInteractions(null);
	};

	/** Stable felt252 commitment derived from the current drug list */
	const commitment = useMemo(() => drugListToCommitment(drugList), [drugList]);

	/** Highest risk level from the AI analysis (1=Low, 2=Moderate, 3=High) */
	const maxRiskLevel = useMemo(
		() => maxRiskFromInteractions(interactions),
		[interactions],
	);

	const evaluateSafety = async (context: string, lifestyle: string[]) => {
		if (drugList.length < 2) return;
		setLoading(true);
		setInteractions(null);

		try {
			const response = await fetch(
				'https://n8n.geotech.agency/webhook/interaction-check',
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ drugs: drugList, lifestyle, context }),
				},
			);
			if (!response.ok) throw new Error('AI Analysis Failed');

			const data: Interaction[] = await response.json();
			setInteractions(data);
			return true;
		} catch (error) {
			console.error(error);
			alert('Clinical screening failed. Verify n8n connection.');
			return false;
		} finally {
			setLoading(false);
		}
	};

	return {
		drugList,
		interactions,
		loading,
		commitment,
		maxRiskLevel,
		addDrug,
		removeDrug,
		evaluateSafety,
	};
};
