import argparse
import json
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

PAGE_W, _ = letter
AZURE = colors.HexColor('#0078D4')
INK = colors.HexColor('#1F2933')
MUTED = colors.HexColor('#52616D')
LIGHT = colors.HexColor('#D9E2E8')

styles = getSampleStyleSheet()
name_style = ParagraphStyle('Name', fontName='Helvetica-Bold', fontSize=21, leading=23, textColor=INK, spaceAfter=1)
headline_style = ParagraphStyle('Headline', fontName='Helvetica-Bold', fontSize=9.4, leading=11, textColor=AZURE, tracking=0.5, spaceAfter=4)
contact_style = ParagraphStyle('Contact', fontName='Helvetica', fontSize=8.1, leading=9.5, textColor=MUTED, spaceAfter=0)
section_style = ParagraphStyle('Section', fontName='Helvetica-Bold', fontSize=8.8, leading=10, textColor=AZURE, tracking=0.8, spaceBefore=5, spaceAfter=4)
body_style = ParagraphStyle('Body', fontName='Helvetica', fontSize=8.25, leading=10.2, textColor=INK, spaceAfter=2)
small_style = ParagraphStyle('Small', fontName='Helvetica', fontSize=7.8, leading=9.3, textColor=INK, spaceAfter=1)
project_title_style = ParagraphStyle('ProjectTitle', fontName='Helvetica-Bold', fontSize=8.35, leading=9.8, textColor=INK, spaceAfter=0)
project_focus_style = ParagraphStyle('ProjectFocus', fontName='Helvetica-Oblique', fontSize=7.5, leading=9, textColor=MUTED, spaceAfter=1)
role_style = ParagraphStyle('Role', fontName='Helvetica-Bold', fontSize=9.1, leading=10.5, textColor=INK, spaceAfter=0)
scope_style = ParagraphStyle('Scope', fontName='Helvetica-Oblique', fontSize=7.9, leading=9.3, textColor=MUTED, spaceAfter=2)
date_style = ParagraphStyle('Date', fontName='Helvetica-Bold', fontSize=8.0, leading=9.3, textColor=MUTED, alignment=TA_RIGHT)
bullet_style = ParagraphStyle('Bullet', fontName='Helvetica', fontSize=7.95, leading=9.45, textColor=INK, leftIndent=10, firstLineIndent=-6, bulletIndent=2, spaceAfter=1.5)
tech_label = ParagraphStyle('TechLabel', fontName='Helvetica-Bold', fontSize=7.75, leading=9.2, textColor=INK)
tech_body = ParagraphStyle('TechBody', fontName='Helvetica', fontSize=7.65, leading=9.2, textColor=INK)


def section(title):
    return [Paragraph(title.upper(), section_style)]


def header_elements(data):
    contact_parts = []
    for item in data['contact']:
        if '@' in item:
            contact_parts.append(f'<link href="mailto:{item}" color="#52616D">{item}</link>')
        elif item.startswith('github.com/'):
            contact_parts.append(f'<link href="https://{item}" color="#52616D">{item}</link>')
        else:
            contact_parts.append(item)
    contact = '  |  '.join(contact_parts)
    return [
        Paragraph(data['name'], name_style),
        Paragraph(data['headline'], headline_style),
        Paragraph(contact, contact_style),
    ]


def add_rule(story, pad=3):
    rule = Table([['']], colWidths=[7.35 * inch], rowHeights=[0.7])
    rule.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(Spacer(1, pad))
    story.append(rule)
    story.append(Spacer(1, pad))


def project_block(project):
    return KeepTogether([
        Paragraph(project['title'], project_title_style),
        Paragraph(project['focus'], project_focus_style),
        Paragraph(project['description'], small_style),
        Spacer(1, 2),
    ])


def role_header(exp):
    left = Paragraph(f"{exp['company']} - {exp['role']}", role_style)
    right = Paragraph(exp['dates'], date_style)
    table = Table([[left, right]], colWidths=[5.95 * inch, 1.4 * inch], hAlign='LEFT')
    table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    return table


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 7)
    canvas.setFillColor(colors.HexColor('#7B8790'))
    canvas.drawString(doc.leftMargin, 0.34 * inch, 'Holden Jolley | Azure Solution Architect')
    canvas.drawRightString(PAGE_W - doc.rightMargin, 0.34 * inch, f'Page {doc.page}')
    canvas.restoreState()


def build(source_path: Path, output_path: Path):
    data = json.loads(source_path.read_text(encoding='utf-8'))
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=letter,
        rightMargin=0.55 * inch,
        leftMargin=0.55 * inch,
        topMargin=0.45 * inch,
        bottomMargin=0.52 * inch,
        title='Holden Jolley - Azure Solution Architect Resume',
        author='Holden Jolley',
        subject='Azure Solution Architect resume and selected architecture projects',
    )

    story = []
    story += header_elements(data)
    add_rule(story)
    story += section('Summary')
    story.append(Paragraph(data['summary'], body_style))

    story += section('Selected Azure Architecture Projects')
    for project in data['projects']:
        story.append(project_block(project))

    story += section('Certifications')
    for certification in data['certifications']:
        story.append(Paragraph(f'• {certification}', small_style))

    story += section('Architecture & Technology')
    technology_rows = [[Paragraph(label, tech_label), Paragraph(value, tech_body)] for label, value in data['technologies']]
    technology_table = Table(technology_rows, colWidths=[1.45 * inch, 5.9 * inch], hAlign='LEFT')
    technology_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 1.2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1.2),
    ]))
    story.append(technology_table)

    story.append(PageBreak())
    story += header_elements(data)
    add_rule(story)
    story += section('Experience')
    for index, exp in enumerate(data['experience']):
        story.append(role_header(exp))
        if exp.get('scope'):
            story.append(Paragraph(exp['scope'], scope_style))
        for bullet in exp['bullets']:
            story.append(Paragraph(bullet, bullet_style, bulletText='•'))
        if index < len(data['experience']) - 1:
            story.append(Spacer(1, 5))

    story += section('Education')
    education = data['education']
    education_table = Table(
        [[Paragraph(education['school'], role_style), Paragraph(education['dates'], date_style)]],
        colWidths=[5.95 * inch, 1.4 * inch],
        hAlign='LEFT',
    )
    education_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(education_table)
    story.append(Paragraph(education['degree'], scope_style))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)


def main():
    parser = argparse.ArgumentParser(description='Build the portfolio resume PDF from structured JSON source.')
    parser.add_argument('--source', default='resume-source.json')
    parser.add_argument('--output', default='resume.pdf')
    args = parser.parse_args()
    build(Path(args.source), Path(args.output))


if __name__ == '__main__':
    main()
