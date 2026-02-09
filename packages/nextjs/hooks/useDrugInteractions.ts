// packages/nextjs/hooks/useDrugInteractions.ts
import { useState } from 'react';

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
			setInteractions(null); // Reset results on change
		}
	};

	const removeDrug = (drug: string) => {
		setDrugList(prev => prev.filter(d => d !== drug));
		setInteractions(null);
	};

	const evaluateSafety = async (context: string, lifestyle: string[]) => {
		if (drugList.length < 2) return;
		setLoading(true);
		setInteractions(null);

		try {
			const response = await fetch(
				'http://localhost:5678/webhook/interaction-check',
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ drugs: drugList, lifestyle, context }),
				},
			);
			if (!response.ok) throw new Error('AI Analysis Failed');

			const data: Interaction[] = await response.json();
			setInteractions(data);
			return true; // Success
		} catch (error) {
			console.error(error);
			alert('Clinical screening failed. Verify n8n connection.');
			return false; // Failure
		} finally {
			setLoading(false);
		}
	};

	return {
		drugList,
		interactions,
		loading,
		addDrug,
		removeDrug,
		evaluateSafety,
	};
};
