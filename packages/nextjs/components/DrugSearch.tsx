'use client';

import { useState, useEffect } from 'react';
import { Search, Loader2, Pill } from 'lucide-react';
import { Command } from 'cmdk';

// 1. Define the Props Interface
interface DrugSearchProps {
	onAddDrug: (drug: string) => void;
	disabled?: boolean;
}

// 2. Define the API Response Type (based on Clinical Tables API)
type RxTermsResponse = [number, string[], any[], any[], any[]];

const DrugSearch = ({ onAddDrug, disabled }: DrugSearchProps) => {
	const [open, setOpen] = useState<boolean>(false);
	const [inputValue, setInputValue] = useState<string>('');
	const [suggestions, setSuggestions] = useState<string[]>([]);
	const [loading, setLoading] = useState<boolean>(false);

	useEffect(() => {
		const fetchDrugs = async () => {
			if (inputValue.length < 2) {
				setSuggestions([]);
				return;
			}

			setLoading(true);
			try {
				const searchRes = await fetch(
					`https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=${encodeURIComponent(inputValue)}&maxList=10`,
				);

				// Cast the response to our defined type
				const data = (await searchRes.json()) as RxTermsResponse;

				if (data[1] && data[1].length > 0) {
					setSuggestions(data[1]);
				} else {
					setSuggestions([]);
				}
			} catch (error) {
				console.error('Failed to fetch drugs', error);
				setSuggestions([]);
			} finally {
				setLoading(false);
			}
		};

		const timeoutId = setTimeout(fetchDrugs, 300);
		return () => clearTimeout(timeoutId);
	}, [inputValue]);

	return (
		<div className='relative group w-full z-50'>
			<div className='absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none z-10'>
				{loading ? (
					<Loader2 className='h-5 w-5 text-indigo-500 animate-spin' />
				) : (
					<Search className='h-5 w-5 text-slate-500 group-focus-within:text-indigo-400 transition-colors' />
				)}
			</div>

			<Command
				className='relative overflow-visible'
				label='Drug Search Command'
			>
				<Command.Input
					value={inputValue}
					onValueChange={(val: string) => {
						setInputValue(val);
						setOpen(!!val);
					}}
					disabled={disabled}
					placeholder='e.g. Lisinopril, Metformin...'
					className='block w-full pl-12 pr-4 py-4 bg-slate-950/50 border border-slate-700/50 rounded-xl text-slate-100 placeholder-slate-600 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 focus:outline-none transition-all'
				/>

				{open && suggestions.length > 0 && (
					<div className='absolute top-full mt-2 w-full bg-slate-900 border border-slate-700 rounded-xl shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200'>
						<Command.List className='max-h-72 overflow-y-auto p-2'>
							{suggestions.map(drug => (
								<Command.Item
									key={drug}
									value={drug}
									onSelect={(currentValue: string) => {
										onAddDrug(currentValue);
										setInputValue('');
										setOpen(false);
									}}
									className='flex items-center gap-3 px-4 py-3 rounded-lg text-slate-300 hover:bg-indigo-600/20 hover:text-white cursor-pointer transition-colors aria-selected:bg-indigo-600/20 aria-selected:text-white'
								>
									<Pill className='w-4 h-4 opacity-50' />
									<span>{drug}</span>
								</Command.Item>
							))}
						</Command.List>
					</div>
				)}
			</Command>
		</div>
	);
};

export default DrugSearch;
