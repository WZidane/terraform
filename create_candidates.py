import boto3
import uuid
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

# --- CONFIGURATION ---
BUCKET_NAME = "voteka-documents-2cb8dfe1"
DYNAMODB_TABLE = "Users"
REGION = "eu-north-1"

candidates = [
    {"name": "Alice Dupont", "text": "Alice souhaite améliorer l'éducation et la santé publique.\nVotez pour un futur meilleur !"},
    {"name": "Bob Martin", "text": "Bob veut renforcer l'économie locale et soutenir les PME.\nVotez pour Bob !"},
    {"name": "Caroline Petit", "text": "Caroline est engagée pour l'environnement et la transition énergétique.\nVotez pour Caroline !"}
]

# --- AWS CLIENTS ---
s3 = boto3.client("s3", region_name=REGION)
dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

# --- FONCTION POUR GENERER PDF ---
def create_candidate_pdf(filename, candidate_name, campaign_text):
    c = canvas.Canvas(filename, pagesize=A4)
    width, height = A4
    c.setFont("Helvetica-Bold", 24)
    c.drawCentredString(width / 2, height - 100, "Document de campagne")
    c.setFont("Helvetica-Bold", 18)
    c.drawString(100, height - 150, f"Candidat : {candidate_name}")
    c.setFont("Helvetica", 14)
    text = c.beginText(100, height - 200)
    text.setLeading(18)
    for line in campaign_text.split("\n"):
        text.textLine(line)
    c.drawText(text)
    c.save()

# --- SCRIPT PRINCIPAL ---
for cand in candidates:
    user_id = str(uuid.uuid4())
    pdf_filename = f"{cand['name'].replace(' ', '_')}.pdf"
    
    # Générer PDF
    create_candidate_pdf(pdf_filename, cand["name"], cand["text"])
    
    # Upload S3
    s3_key = f"{pdf_filename}"
    s3.upload_file(pdf_filename, BUCKET_NAME, s3_key)
    s3_url = f`s3://{BUCKET_NAME}/{s3_key}`
    
    # Ajouter item DynamoDB (Users)
    table.put_item(Item={
        "id": user_id,
        "name": cand["name"],
        "document_s3": s3_url
    })
    
    print(f"User créé : {cand['name']} avec ID {user_id} et document {s3_url}")