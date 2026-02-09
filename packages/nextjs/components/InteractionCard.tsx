// packages/nextjs/components/InteractionCard.tsx
import { BookOpen, ExternalLink } from 'lucide-react';
import { Interaction } from '../hooks/useDrugInteractions';

// Helper: Clean Display Text
const cleanCitationText = (text: string): string => {
	return (
		text
			.replace(/\[(.*?)\]\(.*?\)/g, '$1')
			.replace(/(https?:\/\/[^\s)]+)/g, '')
			.trim() || 'Clinical Source'
	);
};

// Helper: Generate DIRECT NCBI PMC Search URL
const getSearchUrl = (interaction: Interaction) => {
  const drugs = interaction.drugs.join(' ');
  // This constructs a Google search for the specific interaction mechanism
  const query = `${drugs} interaction mechanism ${interaction.mechanism}`;
  
  return `https://www.google.com/search?q=${encodeURIComponent(query)}`;
};

export const InteractionCard = ({
	interaction,
}: {
	interaction: Interaction;
}) => {
	return (
		<div className='bg-slate-950/50 border border-white/5 rounded-xl overflow-hidden group hover:border-white/10 transition-colors'>
			{/* Header */}
			<div
				className={`px-4 py-3 flex justify-between items-center border-b border-white/5 ${
					interaction.severity === 'High' ? 'bg-red-500/5' : 'bg-amber-500/5'
				}`}
			>
				<span
					className={`text-xs font-bold uppercase tracking-wider px-2 py-0.5 rounded ${
						interaction.severity === 'High'
							? 'bg-red-500/20 text-red-400'
							: 'bg-amber-500/20 text-amber-400'
					}`}
				>
					{interaction.severity}
				</span>
				<span className='text-[10px] text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20'>
					Confidence: {interaction.confidence || 95}%
				</span>
			</div>

			{/* Body */}
			<div className='p-4 space-y-3'>
				<h3 className='font-bold text-slate-200'>
					{interaction.drugs.join(' + ')}
				</h3>
				<p className='text-sm text-slate-400 leading-relaxed'>
					{interaction.description}
				</p>

				<div className='bg-slate-900 rounded-lg p-3 text-xs border border-white/5'>
					<span className='text-slate-500 font-bold block mb-1 uppercase'>
						Mechanism
					</span>
					<span className='text-slate-300'>{interaction.mechanism}</span>
				</div>

				<div className='bg-emerald-500/5 rounded-lg p-3 text-xs border border-emerald-500/10'>
					<span className='text-emerald-500/70 font-bold block mb-1 uppercase'>
						Recommendation
					</span>
					<span className='text-emerald-300'>{interaction.alternatives}</span>
				</div>

				{/* Citations */}
				<div className='pt-2 border-t border-white/5 mt-2'>
					<details className='group/details'>
						<summary className='text-[10px] text-slate-500 uppercase font-bold tracking-wider cursor-pointer flex items-center gap-2 hover:text-indigo-400 transition-colors'>
							<BookOpen className='w-3 h-3' /> Sources
						</summary>
						<div className='mt-2 pl-2 space-y-2'>
							{interaction.citations?.map((cite, cIdx) => (
								<div
									key={cIdx}
									className='flex items-center gap-3'
								>
									<a
										href={getSearchUrl(interaction)}
										target='_blank'
										rel='noopener noreferrer'
										className='flex items-center gap-2 text-xs text-indigo-300 hover:text-indigo-200 hover:underline truncate max-w-full'
									>
										<ExternalLink className='w-3 h-3 shrink-0' />
										{cleanCitationText(cite)}
									</a>
								</div>
							))}
						</div>
					</details>
				</div>
			</div>
		</div>
	);
};
