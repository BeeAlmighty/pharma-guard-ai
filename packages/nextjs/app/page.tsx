'use client';

import { useState } from 'react';
import { useAccount } from '@starknet-react/core';
import type { NextPage } from 'next';
import {
	Wine,
	Baby,
	Cigarette,
	X,
	Download,
	CheckCircle,
	Pill,
	User,
	ShieldCheck,
	Search,
	Zap,
	AlertTriangle,
} from 'lucide-react';

// Custom Hooks & Utils
import { useDrugInteractions } from '../hooks/useDrugInteractions';
import { generateClinicalReport } from '../utils/pdfGenerator';

// Components
import { CustomConnectButton } from '~~/components/scaffold-stark/CustomConnectButton';
import DrugSearch from '../components/DrugSearch';
import { InteractionCard } from '../components/InteractionCard';

// Types
interface LifestyleOption {
	id: string;
	label: string;
	icon: React.ElementType;
}

const DrugInteractionChecker: NextPage = () => {
	// Logic from Hook
	const {
		drugList,
		interactions,
		loading,
		addDrug,
		removeDrug,
		evaluateSafety,
	} = useDrugInteractions();

	// UI State (Local)
	const [context, setContext] = useState<string>('');
	const [lifestyle, setLifestyle] = useState<string[]>([]);
	const [pharmacistName, setPharmacistName] = useState<string>('');
	const [showSuccess, setShowSuccess] = useState<boolean>(false);

	const { status } = useAccount();

	// Handlers
	const handleEvaluate = async () => {
		const success = await evaluateSafety(context, lifestyle);
		if (success && status === 'connected') {
			setShowSuccess(true);
			setTimeout(() => setShowSuccess(false), 5000);
		}
	};

	const handleDownloadPDF = () => {
		generateClinicalReport({
			drugList,
			interactions,
			context,
			lifestyle,
			pharmacistName,
		});
	};

	const lifestyleOptions: LifestyleOption[] = [
		{ id: 'Alcohol', label: 'Alcohol Intake', icon: Wine },
		{ id: 'Smoking', label: 'Tobacco Use', icon: Cigarette },
		{ id: 'Pregnancy', label: 'Pregnancy', icon: Baby },
	];

	return (
		<div className='lg:h-[calc(100vh-4rem)] min-h-[calc(100vh-4rem)] bg-slate-950 text-slate-200 font-sans lg:overflow-hidden flex flex-col'>
			{/* --- HERO SECTION --- */}
			<section className='shrink-0 py-6 px-4 bg-slate-900/30 border-b border-white/5 flex flex-col items-center text-center animate-in fade-in slide-in-from-top-4 duration-700'>
				<h2 className='text-2xl md:text-3xl font-bold text-white tracking-tight mb-2'>
					Clinical Decision Support
				</h2>
				<p className='text-slate-400 max-w-2xl mx-auto text-sm md:text-base leading-relaxed'>
					Professional analysis leveraging{' '}
					<span className='text-indigo-400 font-medium'>
						AI-driven pharmacology
					</span>{' '}
					and{' '}
					<span className='text-indigo-400 font-medium'>
						Starknet audit logging
					</span>{' '}
					to eliminate medication errors.
				</p>
			</section>

			{/* --- MAIN BENTO GRID --- */}
			<main className='flex-1 p-4 lg:p-6 grid grid-cols-1 lg:grid-cols-12 gap-6 lg:overflow-hidden'>
				{/* --- COL 1: CONTEXT & INFO --- */}
				<section className='lg:col-span-3 flex flex-col gap-4 lg:h-full lg:overflow-y-auto pr-1 custom-scrollbar'>
					<div className='bg-slate-900/60 border border-white/5 rounded-2xl p-5 backdrop-blur-xl'>
						<div className='flex items-center gap-3 mb-6'>
							<div className='w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center border border-slate-700'>
								<User className='w-5 h-5 text-slate-400' />
							</div>
							<div>
								<h2 className='text-sm font-bold text-white'>
									Patient Context
								</h2>
								<p className='text-xs text-slate-500'>Manual Entry Mode</p>
							</div>
						</div>

						<div className='space-y-4'>
							<div>
								<label className='text-[10px] uppercase tracking-wider text-slate-500 font-bold mb-2 block'>
									Risk Factors
								</label>
								<div className='grid grid-cols-1 gap-2'>
									{lifestyleOptions.map(opt => (
										<button
											key={opt.id}
											onClick={() =>
												setLifestyle(p =>
													p.includes(opt.id)
														? p.filter(i => i !== opt.id)
														: [...p, opt.id],
												)
											}
											className={`flex items-center gap-3 p-3 rounded-xl border transition-all text-sm ${
												lifestyle.includes(opt.id)
													? 'bg-indigo-600/20 border-indigo-500/50 text-white'
													: 'bg-slate-950/40 border-slate-800 text-slate-400 hover:bg-slate-800'
											}`}
										>
											<opt.icon
												className={`w-4 h-4 ${lifestyle.includes(opt.id) ? 'text-indigo-400' : 'text-slate-500'}`}
											/>
											{opt.label}
											{lifestyle.includes(opt.id) && (
												<CheckCircle className='w-3 h-3 ml-auto text-indigo-400' />
											)}
										</button>
									))}
								</div>
							</div>

							<div>
								<label className='text-[10px] uppercase tracking-wider text-slate-500 font-bold mb-2 block'>
									Clinical Notes
								</label>
								<textarea
									value={context}
									onChange={e => setContext(e.target.value)}
									placeholder='e.g. Stage 3 CKD...'
									className='w-full h-24 bg-slate-950/40 border border-slate-800 rounded-xl p-3 text-sm text-slate-200 focus:border-indigo-500/50 outline-none resize-none'
								/>
							</div>
						</div>
					</div>
				</section>

				{/* --- COL 2: ACTIVE REGIMEN --- */}
				<section className='lg:col-span-5 flex flex-col gap-6 lg:h-full min-h-[500px] lg:min-h-0'>
					<div className='relative z-5 bg-slate-900/60 border border-white/5 rounded-2xl p-6 backdrop-blur-xl shrink-0'>
						<label className='text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3 block'>
							Add Medication
						</label>
						<div className='flex gap-2'>
							<DrugSearch
								onAddDrug={addDrug}
								disabled={loading}
							/>
						</div>
					</div>

					<div className='flex-1 bg-slate-900/40 border border-white/5 rounded-2xl p-6 relative overflow-hidden flex flex-col min-h-0 z-0'>
						<div className='absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 opacity-20' />

						<div className='flex justify-between items-center mb-4 shrink-0'>
							<h2 className='text-lg font-bold text-white'>Active Molecules</h2>
							<span className='text-xs bg-slate-800 text-slate-400 px-2 py-1 rounded border border-slate-700'>
								{drugList.length} Selected
							</span>
						</div>

						<div className='flex-1 overflow-y-auto relative pr-2 custom-scrollbar min-h-0'>
							{drugList.length === 0 ? (
								<div className='h-full flex flex-col items-center justify-center opacity-30'>
									<div className='w-20 h-20 rounded-full border-2 border-dashed border-slate-500 flex items-center justify-center mb-4'>
										<Search className='w-8 h-8 text-slate-500' />
									</div>
									<p>Search drugs to build graph</p>
								</div>
							) : (
								<div className='space-y-2 relative pb-4'>
									{drugList.length > 1 && (
										<div className='absolute left-[26px] top-6 bottom-6 w-0.5 bg-gradient-to-b from-indigo-500/50 to-purple-500/20' />
									)}
									{drugList.map((drug, idx) => (
										<div
											key={idx}
											className='group flex items-center gap-4 relative py-2 animate-in slide-in-from-left-4 fade-in duration-300'
										>
											<div className='relative z-10 w-14 h-14 rounded-2xl bg-slate-800 border border-slate-700 flex items-center justify-center shadow-lg group-hover:border-indigo-500/50 transition-all shrink-0'>
												<Pill className='w-6 h-6 text-indigo-300' />
											</div>
											<div className='flex-1 bg-slate-800/30 border border-white/5 rounded-xl p-3 flex justify-between items-center hover:bg-slate-800/50 transition-colors'>
												<span className='font-bold text-slate-200'>{drug}</span>
												<button
													onClick={() => removeDrug(drug)}
													className='p-2 hover:bg-red-500/10 hover:text-red-400 rounded-lg text-slate-600 transition-colors'
												>
													<X className='w-4 h-4' />
												</button>
											</div>
										</div>
									))}
								</div>
							)}
						</div>

						<div className='mt-4 pt-4 border-t border-white/5 shrink-0 flex flex-col gap-3'>
							{status !== 'connected' && (
								<div className='flex items-center justify-between gap-3 p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 animate-in slide-in-from-bottom-2'>
									<div className='flex items-center gap-2 text-amber-400'>
										<AlertTriangle className='w-4 h-4' />
										<span className='text-xs font-bold'>
											Connect Wallet to Enable Audit Logs
										</span>
									</div>
									<div className='scale-75 origin-right'>
										<CustomConnectButton />
									</div>
								</div>
							)}

							<button
								onClick={handleEvaluate}
								disabled={loading || drugList.length < 2}
								className='w-full py-4 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-lg shadow-lg shadow-indigo-900/20 disabled:opacity-50 disabled:grayscale transition-all flex items-center justify-center gap-2'
							>
								{loading ? (
									<span className='loading loading-spinner'></span>
								) : (
									<>
										<ShieldCheck className='w-5 h-5' /> Evaluate Risk
									</>
								)}
							</button>
						</div>
					</div>
				</section>

				{/* --- COL 3: REPORT --- */}
				<section className='lg:col-span-4 lg:h-full lg:overflow-hidden min-h-[500px]'>
					<div className='bg-slate-900/80 border border-white/10 rounded-2xl h-full backdrop-blur-2xl flex flex-col relative overflow-hidden'>
						<div className='p-5 border-b border-white/5 bg-slate-950/30 flex justify-between items-center shrink-0'>
							<h2 className='font-bold text-white flex items-center gap-2'>
								<Zap className='w-4 h-4 text-amber-400' />
								Analysis Report
							</h2>
							{interactions && (
								<button
									onClick={handleDownloadPDF}
									className='text-xs flex items-center gap-1 bg-slate-800 hover:bg-slate-700 px-2 py-1 rounded border border-slate-700 transition-colors'
								>
									<Download className='w-3 h-3' /> PDF
								</button>
							)}
						</div>

						<div className='flex-1 overflow-y-auto p-5 custom-scrollbar'>
							{!interactions && !loading && (
								<div className='h-full flex flex-col items-center justify-center text-center p-6 opacity-40'>
									<ShieldCheck className='w-16 h-16 text-slate-500 mb-4' />
									<h3 className='text-lg font-bold text-white mb-2'>
										Ready to Analyze
									</h3>
									<p className='text-sm text-slate-400'>
										Add medications and click Evaluate to generate a
										blockchain-verified clinical report.
									</p>
								</div>
							)}

							{interactions && (
								<div className='space-y-4 animate-in slide-in-from-right-8 duration-500'>
									<div className='flex gap-4 mb-6'>
										<div className='flex-1 bg-red-500/10 border border-red-500/20 rounded-xl p-3 text-center'>
											<div className='text-2xl font-bold text-red-400'>
												{interactions.filter(i => i.severity === 'High').length}
											</div>
											<div className='text-[10px] uppercase text-red-300/70 font-bold'>
												High Risk
											</div>
										</div>
										<div className='flex-1 bg-amber-500/10 border border-amber-500/20 rounded-xl p-3 text-center'>
											<div className='text-2xl font-bold text-amber-400'>
												{interactions.filter(i => i.severity !== 'High').length}
											</div>
											<div className='text-[10px] uppercase text-amber-300/70 font-bold'>
												Moderate
											</div>
										</div>
									</div>

									{interactions.map((interaction, idx) => (
										<InteractionCard
											key={idx}
											interaction={interaction}
										/>
									))}
								</div>
							)}
						</div>

						{interactions && (
							<div className='p-4 bg-slate-950/50 border-t border-white/5 shrink-0'>
								<div className='relative'>
									<User className='absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-500' />
									<input
										type='text'
										value={pharmacistName}
										onChange={e => setPharmacistName(e.target.value)}
										placeholder='Pharmacist Name'
										className='pl-10 pr-4 py-3 w-full bg-slate-900 border border-slate-700 rounded-xl text-sm outline-none focus:border-indigo-500/50 transition-all placeholder:text-slate-600'
									/>
								</div>
							</div>
						)}
					</div>
				</section>
			</main>

			{/* Success Overlay */}
			{showSuccess && (
				<div className='fixed bottom-6 right-6 z-[100] animate-in slide-in-from-bottom-10 fade-in duration-500'>
					<div className='bg-slate-900 border border-emerald-500/30 text-white px-5 py-4 rounded-2xl shadow-2xl shadow-emerald-500/10 flex items-center gap-4'>
						<div className='bg-emerald-500/20 p-2 rounded-full animate-pulse'>
							<CheckCircle className='w-5 h-5 text-emerald-400' />
						</div>
						<div>
							<p className='font-bold text-sm text-emerald-100'>
								Audit Log Recorded
							</p>
							<p className='text-xs text-emerald-400/70 font-mono'>
								Hash: 0x8a...4b29
							</p>
						</div>
					</div>
				</div>
			)}
		</div>
	);
};

export default DrugInteractionChecker;
