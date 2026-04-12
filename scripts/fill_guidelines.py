#!/usr/bin/env python3
"""
根据 yebk.pdf 的内容和每条记录的具体问题/contexts，
为 sft_annotations.todo.jsonl 中的每条记录填写个性化的 annotation_guideline。
"""

import json

# 针对每条记录定制的 annotation_guideline
# 来源策略：基于 mode + 问题主题 + contexts 中的核心信息点
GUIDELINES = {
    "sft-0001": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about the appropriate age for introducing solid foods. "
        "Start with the key recommendation (around 6 months, after the disappearance of the tongue-thrust reflex). "
        "Explain the readiness signs mentioned in the text (sitting upright, tongue-thrust reflex ending). "
        "Describe the initial feeding approach (small amounts, using a spoon). "
        "Cite the supporting references [1][2][3] as evidence."
    ),
    "sft-0002": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about which food types to prioritize when starting solids. "
        "State the traditional recommendation (grains) and the lack of medical evidence for strict food ordering. "
        "Mention the benefit of meat for breastfed babies (iron and zinc). "
        "Emphasize introducing one new food at a time and observing for allergic reactions (diarrhea, rash, vomiting). "
        "Cite the supporting references [1][2][3]."
    ),
    "sft-0003": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about nutritional supplements needed for breastfed babies. "
        "Lead with the key conclusion: breastfed babies need supplemental Vitamin D (400 IU/day from birth). "
        "Address iron: sufficient in the first 4–6 months from birth stores, then introduce iron-rich complementary foods around 6 months. "
        "Note that formula-fed babies generally don't need extra Vitamin D or iron if drinking adequate formula. "
        "Cite the supporting references [1][2][3]."
    ),
    "sft-0004": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about precautions for formula feeding. "
        "Cover feeding posture (semi-upright, never fully flat to avoid choking or ear infections), "
        "nipple flow rate (test with inverted bottle—drip a few drops then stop), "
        "feeding frequency and volume guidelines by age, "
        "and burping frequency (every 60–90 ml for formula-fed babies). "
        "Cite supporting references [1][2][3]."
    ),
    "sft-0005": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about the common causes of burping, hiccups, and spitting up in babies. "
        "Distinguish between normal spit-up (mild reflux, usually harmless) and true vomiting (forceful, distressing). "
        "Explain that swallowed air during feeding is the primary cause of burping. "
        "List the reduction strategies mentioned in the text (frequent burping, upright position after feeding, correct nipple size). "
        "Note the warning signs requiring medical attention (blood in vomit, green/yellow vomit, projectile force). "
        "Cite references [1][2][3]."
    ),
    "sft-0006": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about what parents should actively monitor in a newborn's first days at home. "
        "Focus on the key observation areas: skin color/jaundice (duration thresholds differ for breast vs. formula fed), "
        "hearing responses (startling, calming to voice), "
        "skin tone and muscle laxity anomalies. "
        "Explain the importance of early pediatrician visits and asking questions. "
        "Cite references [1][2][3]."
    ),
    "sft-0007": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about what a newborn's early physical exam typically covers. "
        "Describe the components: heart and lung auscultation, eye/ear/mouth check, abdominal palpation, umbilical cord assessment, "
        "reflexes and muscle tone, hip examination, body measurements (length, weight, head circumference). "
        "Mention the follow-up visit timeline (2–4 weeks). "
        "Cite references [1][2][3]."
    ),
    "sft-0008": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about typical growth and development milestones in the first month. "
        "State the expected weight loss (up to 10% in first 5 days) and recovery (by day 10). "
        "From 1–4 months: weight gain ~0.7–0.9 kg/month, length +2.5–4 cm/month, head circumference +1.25 cm/month. "
        "Describe emerging behaviors (alertness, responding to voices, hand-to-mouth movement, temperament differences). "
        "Mention that development may show spurts and plateaus. "
        "Cite references [1][2][3]."
    ),
    "sft-0009": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about vaccination considerations for babies aged 1–3 months. "
        "Note that the contexts retrieved relate to immunization schedules for older age groups (preschool and 12–18 months). "
        "Provide whatever relevant information is available about vaccine types and scheduling principles. "
        "Acknowledge that specific 1–3 month vaccine details are not fully covered in these excerpts. "
        "Cite references [1][2][3] and note any gaps in evidence."
    ),
    "sft-0010": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about common behavioral developments in babies aged 4–7 months. "
        "Describe the emotional transformation: from passive (eating/sleeping) to more active and outward-focused. "
        "Highlight temperament traits that become more visible (activity level, persistence, adaptability). "
        "Note the developmental leap pattern (progress followed by apparent regression, then another leap). "
        "Mention growth benchmarks (weight, length, head circumference for 1–4 months as reference). "
        "Cite references [1][2][3]."
    ),
    "sft-0011": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about key safety hazards to prevent for babies aged 8 months to 1 year. "
        "Cover the main risk categories mentioned: falls (playground equipment, stairs, windows), "
        "burns (matches, lighters, smoke detectors), "
        "car safety (correct car seat use, no front seat). "
        "Emphasize that safety measures must be updated as the child grows stronger and more curious. "
        "Cite references [1][2][3]."
    ),
    "sft-0012": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about the key caregiving priorities for a 1-year-old. "
        "Focus on child care setting safety standards (clean environment, age-appropriate equipment), "
        "stranger safety education, "
        "supervision during outings, "
        "and the principle that protective measures must evolve as the child develops. "
        "Cite references [1][2][3]."
    ),
    "sft-0013": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about what a pediatric checkup typically covers for 2-year-olds. "
        "Describe the laboratory screenings mentioned (blood lead test, cholesterol, hemoglobin; urine analysis for symptomatic children; tuberculosis skin test based on risk). "
        "List the vaccines that should have been completed by age 2 (hepatitis B, Hib, pneumococcal, rotavirus, DTaP, MMR, varicella, hepatitis A). "
        "Note the frequency of routine checkups (twice yearly starting at 24 months). "
        "Cite references [1][2][3]."
    ),
    "sft-0014": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about health and safety considerations when traveling with children aged 4–5. "
        "Emphasize car seat use (rear seat, 5-point harness, even for short trips). "
        "For air travel: choose direct flights, schedule around nap/sleep times, notify airline in advance. "
        "Mention vision and hearing check schedules relevant to this age group. "
        "Include general safety principles for this age (helmet for bikes, outdoor supervision). "
        "Cite references [1][2][3]."
    ),
    "sft-0015": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about what criteria to evaluate when choosing a childcare facility. "
        "Cover staff qualifications (education, CPR training, vaccines), child-to-staff ratios, "
        "cleanliness and safety of the environment, age-appropriate equipment, "
        "and special-needs accommodations (flexible equipment, trained staff, emergency protocols). "
        "Mention the importance of spending time observing the facility before deciding. "
        "Cite references [1][2][3]."
    ),
    "sft-0016": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about how parents and caregivers should coordinate when a child is sick. "
        "Describe the illness policy options: home care (stay home personally or arrange a trusted caregiver), "
        "family daycare that accepts mildly ill children, "
        "dedicated sick-child care facilities (with separation from healthy children, hygienic practices, on-call pediatrician). "
        "Emphasize medication authorization (signed consent, daily pick-up of medications). "
        "Cite references [1][2][3]."
    ),
    "sft-0017": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about home management approaches for a constipated child. "
        "Recommend high-fiber diet as the first-line approach (daily fiber intake = age in years + 5 grams; 5 servings of fruits/vegetables). "
        "For toilet-trained children: scheduled sitting on the toilet after meals (up to 15 minutes). "
        "Mention age-specific approaches: for infants already on solids (prunes, apricots, high-fiber vegetables). "
        "Caution against using laxatives without medical guidance. "
        "Cite references [1][2][3]."
    ),
    "sft-0018": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about the most important complication to prevent during diarrhea. "
        "State the primary concern is dehydration: fluid and electrolyte loss through damaged intestinal lining. "
        "List prevention and management measures: oral rehydration solutions, avoiding boiled milk, limiting high-sugar and high-salt drinks, monitoring for dehydration signs. "
        "Include public health prevention steps (handwashing, avoiding raw milk, rotavirus vaccine, limiting juice). "
        "Cite references [1][2][3]."
    ),
    "sft-0019": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Identify the specific warning signs that require prompt medical attention for a vomiting child: "
        "signs of dehydration, inability to keep down liquids, vomiting lasting more than 24 hours, "
        "blood or bile-colored vomit, extreme lethargy or irritability, seizures, or jaundice. "
        "Do not recommend self-medication. Emphasize ORS (oral rehydration solution) as the appropriate home measure and clearly state that a doctor must be contacted when the above signs appear. "
        "Include a safety routing note: if the child appears seriously ill or symptoms worsen, seek emergency care immediately. "
        "Cite references [1][2][3]."
    ),
    "sft-0020": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about how parents should manage food allergies in children. "
        "Cover the diagnostic approaches (skin prick test, IgE blood test) and the elimination diet method (remove suspected food, reintroduce one at a time under medical supervision). "
        "Explain the primary treatment: strict avoidance of the allergenic food, with allowance that many children outgrow allergies to milk, eggs, and wheat. "
        "Caution about cross-contamination risks and the need for specialist approval before reintroducing baked goods containing the allergen. "
        "Cite references [1][2][3]."
    ),
    "sft-0021": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "List the specific conditions and warning signs indicating that a coughing child needs more than home observation: "
        "suspected bronchiolitis, respiratory distress, underlying conditions (cystic fibrosis, congenital heart disease, immunodeficiency, prematurity, organ transplant, chemotherapy), "
        "cough that is sudden-onset with fever, cough after choking on an object (foreign body aspiration risk), "
        "cough affecting eating and sleeping, or cough with wheezing, vomiting, or skin blueness. "
        "Include a safety routing note: these situations require timely pediatric evaluation. "
        "Do not recommend over-the-counter cough medications (not advised for children). "
        "Cite references [1][2][3]."
    ),
    "sft-0022": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer comparing management of influenza versus the common cold. "
        "Key differences: flu causes higher fever (≥38.3°C), more severe body aches, and greater systemic illness than a cold. "
        "Management: increased rest, fluids, and light food for flu; children with chronic diseases (heart, lung, kidney, diabetes, blood disorders, cancer) are at higher risk of complications. "
        "Mention that respiratory distress with flu-like symptoms requires immediate medical help. "
        "Note that antivirals are available but not always indicated; avoid aspirin in children. "
        "Cite references [1][2][3]."
    ),
    "sft-0023": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "List the warning signs of pneumonia that parents should watch for: "
        "rapid or labored breathing, skin retractions between ribs, nasal flaring, chest pain (especially when coughing or breathing deeply), wheezing, blue lips or nail beds. "
        "Also note systemic signs: high fever, chills, flushed skin, loss of appetite, extreme fatigue, and increased crying or paleness in infants. "
        "Include a safety routing note: any of these signs—especially breathing difficulty or cyanosis—require immediate medical attention. "
        "Mention the preventive role of the pneumococcal vaccine (PCV13). "
        "Cite references [1][2][3]."
    ),
    "sft-0024": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about home care priorities when a child has a cold or upper respiratory infection. "
        "Focus on: managing nasal congestion (saline drops, nasal aspirator), reducing transmission (frequent handwashing by caregivers, covering coughs, avoiding kissing), "
        "and monitoring for complications (if symptoms persist beyond 2 weeks or ear pain/facial pressure develops, consult a doctor). "
        "Note that colds are spread by respiratory droplets and contact, not cold air. "
        "Mention that breastfeeding provides some immune protection but not complete coverage. "
        "Cite references [1][2][3]."
    ),
    "sft-0025": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer describing the common symptoms of otitis media (middle ear infection). "
        "Cover: ear pain (older children report it; younger ones pull at the ear and cry), increased crying during feeding (sucking increases middle ear pressure), "
        "sleep disturbance, fever (present in ~1/3 of cases, 38–40°C), balance problems, "
        "possible temporary hearing loss (fluid in middle ear), and discharge from the ear (indicating eardrum perforation). "
        "Mention that hearing loss from otitis media is usually temporary. "
        "Cite references [1][2][3]."
    ),
    "sft-0026": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about the correct steps for managing a nosebleed in children. "
        "Step-by-step: stay calm, have the child sit/stand leaning slightly forward, pinch the soft lower part of the nose for at least 10 minutes without releasing to check. "
        "Clearly list what NOT to do: do not tilt head back, do not lay child down, do not pack the nose with gauze or tissue. "
        "State when to contact a doctor (suspicion of excessive blood loss, blood only from mouth, child appears very pale or unresponsive, frequent recurrence with nasal obstruction). "
        "Mention prevention: saline drops and petroleum jelly in dry conditions; humidifier use. "
        "Cite references [1][2][3]."
    ),
    "sft-0027": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Describe the situations requiring urgent medical evaluation for sore throat: "
        "persistent sore throat not relieved by drinking (regardless of fever), high fever with swollen neck glands and tonsillar exudate (suggest strep), "
        "severe difficulty swallowing or drooling (may indicate epiglottitis—a medical emergency), "
        "very young infants (strep presents as thick/bloody nasal discharge with irritability). "
        "Clarify that viral sore throats (most common in infants and toddlers) typically resolve in 7–10 days without antibiotics, "
        "while strep requires a throat culture and antibiotics. "
        "Include a safety routing note: drooling with difficulty swallowing warrants immediate emergency care. "
        "Cite references [1][2][3]."
    ),
    "sft-0028": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Describe the correct first-aid steps for burns/scalds: cool the burn (implied), cover with sterile gauze, and seek medical help. "
        "List what NOT to apply: butter, animal fat, or any folk remedy—these worsen the injury. "
        "State clearly when hospitalization is required: third-degree burns, burns covering ≥10% of body surface, burns to face/hands/feet/genitals/joints, very young or uncooperative child. "
        "Note that all electrical burns, chemical burns, and burns to mouth or genitals require immediate medical treatment. "
        "Include a safety routing note: when in doubt about severity, always contact a doctor. "
        "Cite references [1][2][3]."
    ),
    "sft-0029": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Describe the immediate response to choking/airway obstruction: the text references CPR training as essential—encourage parents to take a CPR course. "
        "Explain the time-sensitivity: if breathing resumes within 2–3 minutes, permanent damage is unlikely; the longer the hypoxia, the greater the risk. "
        "List the signs of partial or residual obstruction (persistent coughing, gagging, wheezing, drooling, swallowing difficulty, breathing difficulty) and state these require emergency pediatric evaluation. "
        "Mention prevention: avoid round/hard foods before age 4, cut food into pieces <1 cm, supervise all meals, no gum for young children. "
        "Include a safety routing note: complete airway obstruction is a life-threatening emergency—call 120 immediately and perform CPR. "
        "Cite references [1][2][3]."
    ),
    "sft-0030": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "List the specific danger signs after a head injury that require immediate medical attention: "
        "unusual sleepiness during normally awake hours, inability to be woken at night, "
        "persistent headache unrelieved by acetaminophen, continuous severe agitation (may indicate severe headache in pre-verbal children), "
        "changes in intellect/coordination/sensation/strength (weak limbs, unsteady gait, slurred speech, strabismus, blurred vision), "
        "loss of consciousness or recurrence of unconsciousness after a lucid interval, seizures, or irregular breathing. "
        "State the emergency procedure: do not move the child (risk of spinal injury), check breathing, apply pressure to scalp lacerations, call 120 and wait. "
        "Include a safety routing note: any loss of consciousness warrants immediate pediatric contact. "
        "Cite references [1][2][3]."
    ),
    "sft-0031": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about how to determine whether a child truly has a fever. "
        "State that rectal temperature ≥38°C is the gold standard for fever (especially in infants). "
        "Other methods (oral, tympanic, temporal artery) also use 38°C as the threshold; axillary temperature uses a lower cutoff. "
        "Explain the measurement process for rectal temperature (lubricant, correct positioning). "
        "Recommend using a digital thermometer and caution that touch-based assessment is unreliable, especially when the child is shivering. "
        "Note that fever is a symptom of disease (often infection), not a disease itself, and serves a protective immune function. "
        "Cite references [1][2][3]."
    ),
    "sft-0032": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Identify the specific circumstances requiring prompt medical contact when a child has a fever: "
        "high fever (≥38.9°C) persisting more than 24 hours even without other symptoms; "
        "fever accompanied by severe sore throat, severe ear pain, unexplained rash, or repeated vomiting/diarrhea; "
        "unusual lethargy or drowsiness; "
        "fever with agitation, hallucinations, or very strange behavior (especially if new); "
        "febrile seizures lasting more than 15 minutes or with breathing difficulty (call 120 immediately). "
        "Include a safety routing note: infants under 3 months with any fever should be seen urgently; older children with high fever and serious symptoms need prompt evaluation. "
        "Cite references [1][2][3]."
    ),
    "sft-0033": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about home care for a child with fever. "
        "Key measures: dress the child lightly, encourage increased fluid intake; "
        "use acetaminophen (dosage by weight and age) if the child is very uncomfortable; "
        "keep the child away from other children until the fever has been gone for more than 24 hours. "
        "Mention that fever itself is not a disease but a symptom—treatment targets comfort, not the number on the thermometer. "
        "Remind parents to monitor for warning signs (per risk_routing criteria) and contact the doctor if high fever persists beyond 24 hours. "
        "Do not recommend aspirin. "
        "Cite references [1][2][3]."
    ),
    "sft-0034": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about which vaccines children need and who coordinates the schedule. "
        "List the vaccines by 2 years old per the contexts: hepatitis B, Hib, pneumococcal, DTaP (diphtheria/tetanus/pertussis), IPV (polio), MMR, varicella, hepatitis A, rotavirus, and annual influenza from 6 months. "
        "State that the pediatrician is the primary coordinator of vaccination schedules and should be consulted for updates (refer to AAP guidelines at www.aap.org). "
        "Reassure parents that combination vaccines given simultaneously are safe and well-researched. "
        "Cite references [1][2][3]."
    ),
    "sft-0035": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about what to do when a child's vaccination schedule changes or is delayed. "
        "State the main action: consult the pediatrician, who will advise on catch-up schedules. "
        "Reassure parents that receiving multiple vaccines at once is safe and supported by evidence. "
        "If an unusual or severe reaction (high fever or behavior change) occurred after a previous dose, discuss precautions for future doses with the doctor. "
        "Emphasize that preventing vaccine-preventable diseases is safer than skipping vaccines. "
        "Cite references [1][2][3]."
    ),
    "sft-0036": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about how a baby's sleep pattern gradually evolves. "
        "Describe the progression: newborns sleep in 3–4 hour cycles without day/night distinction; "
        "by ~6 weeks, the longest sleep period shifts to night (3–5 hours); "
        "by 10–12 months, morning napping begins to fade for some babies; "
        "by 13–23 months, most children transition to one afternoon nap. "
        "Mention that development spurts can temporarily disrupt established sleep patterns (e.g., a child sleeping through the night suddenly waking for night feeds). "
        "Cite references [1][2][3]."
    ),
    "sft-0037": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about how parents can establish a stable bedtime routine for babies. "
        "The routine can begin from 4–6 months and should include calming, consistent activities in sequence "
        "(e.g., bath, massage, lullaby or soft music, dim lights, last feed, short bedtime story). "
        "Emphasize that timing is more important than the specific activity chosen: put the baby to bed when biologically ready (watch for sleep cues). "
        "Avoid high-stimulation play before bedtime. "
        "Both parents should agree on and consistently follow the chosen routine. "
        "Cite references [1][2][3]."
    ),
    "sft-0038": (
        "Based only on the retrieved contexts from yebk.pdf, provide a grounded answer about which habits families can adjust first when a child wakes frequently at night. "
        "Identify common causes: changes in bedtime ritual, room/bed change, loss of comfort object, travel, or illness. "
        "First steps: re-establish the consistent bedtime routine, slightly advance bedtime (by 20–30 minutes), "
        "avoid taking the child into the parent's bed as a response (it can become a lasting habit). "
        "For persistent disruption (e.g., due to grandparent visit or illness), consider a one-night 'reset' (very early bedtime, let the child work through protest crying). "
        "Mention that gradual changes are easier for both parent and child. "
        "Cite references [1][2][3]."
    ),
    "sft-0039": (
        "Do not make assumptions or guess. "
        "The retrieved contexts from yebk.pdf discuss sleep schedules, nap patterns, and the causes of night waking in general terms (sleep ritual changes, developmental leaps, timing issues), "
        "but they do not provide any evidence linking calcium deficiency to nighttime waking in babies. "
        "State clearly that the available evidence in these contexts is insufficient to confirm or deny that frequent night waking indicates calcium deficiency. "
        "Explain what is missing: the contexts contain no content about calcium metabolism, deficiency symptoms, or their relationship to infant sleep. "
        "Recommend consulting a pediatrician for a proper nutritional evaluation if calcium deficiency is genuinely suspected. "
        "Keep the answer conservative and avoid speculation."
    ),
    "sft-0040": (
        "Answer conservatively based only on the retrieved contexts from yebk.pdf. "
        "Describe the situations where home adjustments alone are insufficient for a child's sleep problems: "
        "when the child's chronic sleep deprivation is affecting daytime functioning (persistent lethargy, extreme irritability, inability to cope); "
        "when parents are experiencing significant burnout or depression due to sleep disruption (described as a risk in the text); "
        "when standard behavior-based strategies (consistent routine, earlier bedtime, one-night reset) have been tried and failed repeatedly. "
        "Recommend consulting the pediatrician or a specialist in pediatric sleep medicine available at many pediatric centers. "
        "Include a safety routing note: long-term sleep deprivation can have lasting consequences for child development—early intervention is better than waiting. "
        "Cite references [1][2][3]."
    ),
}


def fill_guidelines(input_path: str, output_path: str):
    updated_records = []
    with open(input_path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            sample_id = record.get("sample_id")
            if sample_id in GUIDELINES:
                record["annotation_guideline"] = GUIDELINES[sample_id]
                print(f"✓ {sample_id}: guideline updated")
            else:
                print(f"⚠ {sample_id}: no custom guideline found, keeping original")
            updated_records.append(record)

    with open(output_path, "w", encoding="utf-8") as f:
        for record in updated_records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")

    print(f"\nDone. {len(updated_records)} records written to {output_path}")


if __name__ == "__main__":
    import os
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    input_file = os.path.join(base, "data", "sft_annotations.todo.jsonl")
    output_file = os.path.join(base, "data", "sft_annotations.todo.jsonl")
    fill_guidelines(input_file, output_file)
