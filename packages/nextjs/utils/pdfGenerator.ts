// packages/nextjs/utils/pdfGenerator.ts
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { Interaction } from '../hooks/useDrugInteractions';

interface PDFParams {
	drugList: string[];
	interactions: Interaction[] | null;
	context: string;
	lifestyle: string[];
	pharmacistName: string;
}

export const generateClinicalReport = ({
	drugList,
	interactions,
	context,
	lifestyle,
	pharmacistName,
}: PDFParams) => {
	const doc = new jsPDF();
	const today = new Date().toLocaleDateString();
	let yPos = 20;

	// Header
	doc.setFontSize(22);
	doc.setTextColor(44, 62, 80);
	doc.text('InteractionCheck Clinical Report', 14, yPos);
	yPos += 8;
	doc.setFontSize(10);
	doc.setTextColor(100);
	doc.text(`Generated: ${today}`, 14, yPos);

	// Divider
	yPos += 15;
	doc.setDrawColor(200);
	doc.line(14, yPos - 5, 196, yPos - 5);

	// Context
	doc.setFontSize(12);
	doc.setTextColor(0);
	doc.text('Clinical Context:', 14, yPos);
	yPos += 6;
	doc.setFontSize(10);
	doc.setTextColor(80);
	const safeContext = context || 'No specific context provided.';
	const safeLifestyle = lifestyle.length > 0 ? lifestyle.join(', ') : 'None';
	doc.text(`Patient Notes: ${safeContext}`, 14, yPos);
	yPos += 6;
	doc.text(`Risk Factors: ${safeLifestyle}`, 14, yPos);

	// Regimen
	yPos += 15;
	doc.setFontSize(12);
	doc.setTextColor(0);
	doc.text('Current Regimen:', 14, yPos);
	yPos += 6;
	doc.setFontSize(10);
	doc.setTextColor(80);
	doc.text(drugList.join(', '), 14, yPos);

	// Table
	if (interactions && interactions.length > 0) {
		const tableData = interactions.map(item => [
			item.severity,
			item.drugs.join(' + '),
			item.description,
			item.mechanism,
			item.alternatives,
		]);

		autoTable(doc, {
			startY: yPos + 10,
			head: [
				[
					'Severity',
					'Interaction',
					'Clinical Effect',
					'Mechanism',
					'Recommendation',
				],
			],
			body: tableData,
			theme: 'grid',
			headStyles: { fillColor: [79, 70, 229] },
			styles: { fontSize: 9, cellPadding: 3 },
			columnStyles: {
				0: { fontStyle: 'bold', textColor: [220, 38, 38], cellWidth: 20 },
				4: { fontStyle: 'italic', textColor: [21, 128, 61] },
			},
		});
	} else {
		yPos += 10;
		doc.text('No significant interactions found.', 14, yPos);
	}

	// Footer / Signature
	// @ts-ignore
	const finalY = (doc as any).lastAutoTable?.finalY || yPos + 20;
	const sigY = finalY + 30;
	doc.setDrawColor(0);
	doc.setLineWidth(0.5);
	doc.line(14, sigY, 100, sigY);
	doc.setFontSize(11);
	doc.setTextColor(0);
	const signer = pharmacistName.trim()
		? `Pharm. ${pharmacistName}`
		: 'Pharm. __________________';
	doc.text(signer, 14, sigY + 10);
	doc.setFontSize(9);
	doc.setTextColor(100);
	doc.text('Verified by Pharmacist', 14, sigY + 15);

	doc.save('Clinical_Interaction_Report.pdf');
};
