"""
BloodLink AI - Full AI Backend API
FastAPI backend with:
  1. Donor Prioritization
  2. Blood Demand Prediction (seasonal/historical)
  3. Emergency Priority Detection
  4. AI Chat Assistant
  5. Fraud Prevention
  6. Ambulance Auto-Assignment & ETA
"""
import os
import math
import random
from datetime import datetime, timedelta
from typing import Optional
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai

# Configure Gemini
GENAI_API_KEY = os.getenv("GEMINI_API_KEY", "")
if GENAI_API_KEY:
    genai.configure(api_key=GENAI_API_KEY)

app = FastAPI(
    title="BloodLink AI – Full Intelligence API",
    description="AI-powered emergency blood network with demand prediction, chat, fraud detection, and smart ambulance routing",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = os.environ.get("BLOODLINK_API_KEY", "bloodlink-demo-key-2024")


# ============ Models ============

class Location(BaseModel):
    lat: float
    lng: float

class DonorInput(BaseModel):
    id: str
    name: str
    blood_group: str
    lat: float
    lng: float
    last_donation_date: Optional[str] = None
    response_count: int = 0
    acceptance_rate: float = 1.0
    is_available: bool = True

class PrioritizeRequest(BaseModel):
    blood_group: str
    location: Location
    donors: list[DonorInput]
    max_radius_km: float = 20.0
    urgency: str = "Normal"

class PredictionResult(BaseModel):
    donor_id: str
    donor_name: str
    score: float
    distance_km: float
    reasoning: str

class DemandPredictionInput(BaseModel):
    historical_requests: list[dict]  # {blood_group, date, units, urgency}
    current_month: Optional[int] = None

class DemandPredictionResult(BaseModel):
    blood_group: str
    predicted_demand: int
    confidence: float
    trend: str  # rising, falling, stable
    seasonal_factor: str
    reasoning: str

class EmergencyClassifyInput(BaseModel):
    patient_age: Optional[int] = None
    patient_condition: Optional[str] = None
    units_needed: int = 1
    blood_group: str = ""
    is_surgery: bool = False
    is_accident: bool = False
    hemoglobin_level: Optional[float] = None
    is_pregnant: bool = False
    time_critical_hours: Optional[float] = None

class EmergencyClassifyResult(BaseModel):
    priority: str  # Normal, Urgent, Critical, SOS
    priority_score: float
    reasoning: list[str]
    recommended_actions: list[str]

class ChatMessage(BaseModel):
    message: str
    user_role: Optional[str] = "donor"
    user_blood_group: Optional[str] = None
    user_lat: Optional[float] = None
    user_lng: Optional[float] = None
    context_data: Optional[dict] = None

class ChatResponse(BaseModel):
    reply: str
    suggestions: list[str]
    action_type: Optional[str] = None  # navigate, call, search, info
    action_data: Optional[dict] = None

class FraudCheckInput(BaseModel):
    user_id: str
    action: str  # donate, request
    donation_count_30d: int = 0
    request_count_24h: int = 0
    account_age_days: int = 0
    location_changes_24h: int = 0
    ip_address: Optional[str] = None
    device_id: Optional[str] = None
    previous_rejections: int = 0

class FraudCheckResult(BaseModel):
    is_suspicious: bool
    risk_score: float  # 0-100
    risk_level: str  # low, medium, high, critical
    flags: list[str]
    recommendation: str

class AmbulanceInput(BaseModel):
    id: str
    lat: float
    lng: float
    is_available: bool = True
    vehicle_type: str = "basic"  # basic, advanced, mobile_icu

class AmbulanceAssignInput(BaseModel):
    request_location: Location
    hospital_location: Location
    ambulances: list[AmbulanceInput]
    urgency: str = "Normal"

class AmbulanceAssignResult(BaseModel):
    ambulance_id: str
    distance_km: float
    eta_minutes: int
    route_score: float
    reasoning: str


# ============ Utility Functions ============

def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

BLOOD_COMPAT = {
    "O-": ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"],
    "O+": ["O+", "A+", "B+", "AB+"],
    "A-": ["A-", "A+", "AB-", "AB+"],
    "A+": ["A+", "AB+"],
    "B-": ["B-", "B+", "AB-", "AB+"],
    "B+": ["B+", "AB+"],
    "AB-": ["AB-", "AB+"],
    "AB+": ["AB+"],
}

# Seasonal demand patterns (month -> multiplier per blood group)
SEASONAL_PATTERNS = {
    1: {"O+": 1.3, "O-": 1.2, "A+": 1.1, "B+": 1.0, "AB+": 0.9, "A-": 1.1, "B-": 1.0, "AB-": 0.9},  # Winter - flu
    2: {"O+": 1.2, "O-": 1.1, "A+": 1.0, "B+": 1.0, "AB+": 0.9, "A-": 1.0, "B-": 1.0, "AB-": 0.9},
    3: {"O+": 1.0, "O-": 1.0, "A+": 1.0, "B+": 1.0, "AB+": 1.0, "A-": 1.0, "B-": 1.0, "AB-": 1.0},  # Spring
    4: {"O+": 1.1, "O-": 1.0, "A+": 1.1, "B+": 1.0, "AB+": 1.0, "A-": 1.0, "B-": 1.0, "AB-": 1.0},
    5: {"O+": 1.2, "O-": 1.1, "A+": 1.1, "B+": 1.1, "AB+": 1.0, "A-": 1.0, "B-": 1.0, "AB-": 1.0},  # Summer accidents
    6: {"O+": 1.4, "O-": 1.3, "A+": 1.2, "B+": 1.2, "AB+": 1.1, "A-": 1.1, "B-": 1.1, "AB-": 1.0},
    7: {"O+": 1.5, "O-": 1.4, "A+": 1.3, "B+": 1.2, "AB+": 1.1, "A-": 1.2, "B-": 1.1, "AB-": 1.0},  # Peak summer
    8: {"O+": 1.3, "O-": 1.2, "A+": 1.2, "B+": 1.1, "AB+": 1.0, "A-": 1.1, "B-": 1.0, "AB-": 1.0},
    9: {"O+": 1.1, "O-": 1.0, "A+": 1.0, "B+": 1.1, "AB+": 1.0, "A-": 1.0, "B-": 1.1, "AB-": 1.0},  # Monsoon dengue
    10: {"O+": 1.2, "O-": 1.1, "A+": 1.1, "B+": 1.2, "AB+": 1.1, "A-": 1.0, "B-": 1.2, "AB-": 1.0},  # Festive season
    11: {"O+": 1.3, "O-": 1.2, "A+": 1.2, "B+": 1.1, "AB+": 1.0, "A-": 1.1, "B-": 1.0, "AB-": 1.0},
    12: {"O+": 1.4, "O-": 1.3, "A+": 1.2, "B+": 1.1, "AB+": 1.0, "A-": 1.2, "B-": 1.1, "AB-": 1.0},  # Winter holidays
}

SEASON_NAMES = {
    1: "Winter (Flu Season)", 2: "Late Winter", 3: "Spring",
    4: "Early Summer", 5: "Summer", 6: "Peak Summer (Accidents ↑)",
    7: "Peak Summer (Highest Demand)", 8: "Late Summer", 9: "Monsoon (Dengue Risk)",
    10: "Festive Season (Accidents ↑)", 11: "Pre-Winter", 12: "Winter (Holiday Season)",
}


def get_compatible_donors(recipient_group: str) -> list[str]:
    return [bg for bg, targets in BLOOD_COMPAT.items() if recipient_group in targets]


def calculate_donor_score(donor, request_lat, request_lng, blood_group, max_radius, urgency):
    distance = haversine(request_lat, request_lng, donor.lat, donor.lng)
    if distance > max_radius:
        return -1, distance, "Too far"

    reasons = []
    score = 0.0

    dist_score = (1 - distance / max_radius) * 35
    score += dist_score
    reasons.append(f"Distance: {distance:.1f}km ({dist_score:.1f}pts)")

    if donor.blood_group == blood_group:
        score += 25
        reasons.append("Exact blood match (+25pts)")
    else:
        score += 15
        reasons.append("Compatible blood (+15pts)")

    if donor.last_donation_date:
        try:
            last = datetime.fromisoformat(donor.last_donation_date)
            days = (datetime.now() - last).days
            if days < 56:
                return -1, distance, "Not eligible (donated too recently)"
            recency_score = min(days / 365, 1.0) * 20
            score += recency_score
            reasons.append(f"Last donation {days}d ago ({recency_score:.1f}pts)")
        except ValueError:
            score += 10
    else:
        score += 15
        reasons.append("No prior donation (+15pts)")

    if donor.response_count > 0:
        history_score = donor.acceptance_rate * 20
        score += history_score
        reasons.append(f"Response rate {donor.acceptance_rate:.0%} ({history_score:.1f}pts)")
    else:
        score += 10
        reasons.append("New donor (+10pts)")

    multiplier = {"SOS": 1.5, "Critical": 1.3, "Urgent": 1.1, "Normal": 1.0}
    score *= multiplier.get(urgency, 1.0)

    return score, distance, " | ".join(reasons)


# ============ Endpoints ============

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "BloodLink AI Full Intelligence API",
        "version": "2.0.0",
        "features": ["prioritize", "demand_prediction", "emergency_classify", "chat", "fraud_check", "ambulance_assign"],
    }


# --------------- 1. Donor Prioritization ---------------
@app.post("/api/prioritize", response_model=list[PredictionResult])
async def prioritize_donors(request: PrioritizeRequest, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    compatible_groups = get_compatible_donors(request.blood_group)
    results = []

    for donor in request.donors:
        if not donor.is_available:
            continue
        if donor.blood_group not in compatible_groups:
            continue

        score, distance, reasoning = calculate_donor_score(
            donor, request.location.lat, request.location.lng,
            request.blood_group, request.max_radius_km, request.urgency,
        )

        if score > 0:
            results.append(PredictionResult(
                donor_id=donor.id, donor_name=donor.name,
                score=round(score, 2), distance_km=round(distance, 2),
                reasoning=reasoning,
            ))

    results.sort(key=lambda x: x.score, reverse=True)
    return results


# --------------- 2. Blood Demand Prediction ---------------
@app.post("/api/predict_demand", response_model=list[DemandPredictionResult])
async def predict_demand(request: DemandPredictionInput, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    month = request.current_month or datetime.now().month
    next_month = (month % 12) + 1
    blood_groups = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

    # Analyze historical data
    group_history: dict[str, list[int]] = {bg: [] for bg in blood_groups}
    for req in request.historical_requests:
        bg = req.get("blood_group", "")
        units = req.get("units", 1)
        if bg in group_history:
            group_history[bg].append(units)

    results = []
    for bg in blood_groups:
        history = group_history[bg]
        base_demand = sum(history) / max(len(history), 1) if history else 3

        # Apply seasonal multiplier
        seasonal_mult = SEASONAL_PATTERNS.get(next_month, {}).get(bg, 1.0)
        predicted = max(1, round(base_demand * seasonal_mult))

        # Calculate trend
        if len(history) >= 4:
            recent = sum(history[-2:]) / 2
            older = sum(history[:2]) / 2
            if recent > older * 1.2:
                trend = "rising"
            elif recent < older * 0.8:
                trend = "falling"
            else:
                trend = "stable"
        else:
            trend = "stable"

        confidence = min(0.95, 0.5 + len(history) * 0.05)

        reasons = []
        if history:
            reasons.append(f"Based on {len(history)} historical requests")
        reasons.append(f"Seasonal factor for {SEASON_NAMES.get(next_month, 'Unknown')}: {seasonal_mult:.1f}x")
        if bg in ["O+", "O-"]:
            reasons.append("Universal donor type — always in high demand")
        if trend == "rising":
            reasons.append("⬆ Demand has been increasing recently")
        elif trend == "falling":
            reasons.append("⬇ Demand has been decreasing recently")

        results.append(DemandPredictionResult(
            blood_group=bg,
            predicted_demand=predicted,
            confidence=round(confidence, 2),
            trend=trend,
            seasonal_factor=SEASON_NAMES.get(next_month, "Unknown"),
            reasoning=" | ".join(reasons),
        ))

    results.sort(key=lambda x: x.predicted_demand, reverse=True)
    return results


# --------------- 3. Emergency Priority Classification ---------------
@app.post("/api/classify_emergency", response_model=EmergencyClassifyResult)
async def classify_emergency(request: EmergencyClassifyInput, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    score = 0.0
    reasons = []
    actions = []

    # Units needed
    if request.units_needed >= 5:
        score += 35
        reasons.append(f"High blood requirement: {request.units_needed} units (+35)")
        actions.append("Alert all compatible donors within 50km radius")
    elif request.units_needed >= 3:
        score += 20
        reasons.append(f"Moderate blood requirement: {request.units_needed} units (+20)")
        actions.append("Alert donors within 30km radius")
    else:
        score += 5
        reasons.append(f"Standard requirement: {request.units_needed} unit(s) (+5)")

    # Patient condition keywords
    if request.patient_condition:
        condition = request.patient_condition.lower()
        critical_keywords = ["cardiac", "hemorrhage", "trauma", "crash", "accident", "stroke", "bleeding", "massive", "emergency", "dying", "critical", "unconscious"]
        urgent_keywords = ["surgery", "operation", "transplant", "cancer", "anemia", "delivery", "labour", "labor"]

        crit_matches = [k for k in critical_keywords if k in condition]
        urg_matches = [k for k in urgent_keywords if k in condition]

        if crit_matches:
            score += 30
            reasons.append(f"Critical condition detected: {', '.join(crit_matches)} (+30)")
            actions.append("Dispatch emergency ambulance immediately")
        if urg_matches:
            score += 15
            reasons.append(f"Urgent condition detected: {', '.join(urg_matches)} (+15)")

    # Patient age
    if request.patient_age:
        if request.patient_age < 5 or request.patient_age > 70:
            score += 15
            reasons.append(f"High-risk age group: {request.patient_age} years (+15)")
            actions.append("Prioritize — vulnerable patient")
        elif request.patient_age < 12:
            score += 10
            reasons.append(f"Pediatric patient: {request.patient_age} years (+10)")

    # Surgery/accident flags
    if request.is_accident:
        score += 25
        reasons.append("Accident case (+25)")
        actions.append("Alert trauma team and prepare OR")
    if request.is_surgery:
        score += 15
        reasons.append("Surgical procedure required (+15)")

    # Hemoglobin level
    if request.hemoglobin_level is not None:
        if request.hemoglobin_level < 5:
            score += 30
            reasons.append(f"Critically low hemoglobin: {request.hemoglobin_level} g/dL (+30)")
            actions.append("Immediate transfusion required")
        elif request.hemoglobin_level < 7:
            score += 20
            reasons.append(f"Dangerously low hemoglobin: {request.hemoglobin_level} g/dL (+20)")
        elif request.hemoglobin_level < 9:
            score += 10
            reasons.append(f"Low hemoglobin: {request.hemoglobin_level} g/dL (+10)")

    # Pregnancy
    if request.is_pregnant:
        score += 15
        reasons.append("Pregnant patient — high priority (+15)")
        actions.append("Ensure Rh-compatible blood only")

    # Time criticality
    if request.time_critical_hours is not None:
        if request.time_critical_hours <= 1:
            score += 30
            reasons.append(f"Time critical: {request.time_critical_hours}h window (+30)")
            actions.append("Activate SOS protocol — less than 1 hour")
        elif request.time_critical_hours <= 4:
            score += 15
            reasons.append(f"Time sensitive: {request.time_critical_hours}h window (+15)")

    # Rare blood type bonus
    if request.blood_group in ["AB-", "B-", "O-"]:
        score += 10
        reasons.append(f"Rare blood type {request.blood_group} — limited supply (+10)")
        actions.append(f"Check blood bank inventory for {request.blood_group}")

    # Determine priority
    if score >= 80:
        priority = "SOS"
    elif score >= 50:
        priority = "Critical"
    elif score >= 25:
        priority = "Urgent"
    else:
        priority = "Normal"

    # Add default actions
    if not actions:
        actions.append("Process through standard request queue")
    actions.append(f"Classified as {priority} priority (score: {score:.0f}/100+)")

    return EmergencyClassifyResult(
        priority=priority,
        priority_score=round(min(score, 100), 1),
        reasoning=reasons if reasons else ["Standard blood request — no critical indicators"],
        recommended_actions=actions,
    )


# --------------- 4. AI Chat Assistant ---------------
@app.post("/api/chat", response_model=ChatResponse)
async def chat_assistant(request: ChatMessage, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    msg = request.message.lower().strip()
    role = request.user_role or "donor"
    blood_group = request.user_blood_group

    # --- Real LLM / Hybrid AI chat logic ---
    if GENAI_API_KEY:
        try:
            system_instructions = {
                "donor": "You are the BloodLink AI Assistant for Donors. Focus on their health, encouraging them, ensuring eligibility, and finding nearby places to donate.",
                "hospital": "You are the BloodLink AI Assistant for Hospital Staff. Prioritize clinical efficiency, trauma triage, fast routing, and emergency protocols.",
                "blood_bank": "You are the BloodLink AI Assistant for Blood Banks. Focus on inventory management, logistics, predicting blood demand, and supply chain.",
                "admin": "You are the BloodLink AI Assistant for System Administrators. Provide high-level analytics, system status, and fraud detection insights."
            }
            
            prompt = system_instructions.get(role, system_instructions["donor"])
            if blood_group:
                prompt += f"\nUser's designated blood group is {blood_group}."
                
            model = genai.GenerativeModel(
                model_name="gemini-1.5-flash",
                system_instruction=prompt
            )
            response = model.generate_content(request.message)
            parsed_reply = response.text
            
            action = "info"
            data = {}
            p_msg = parsed_reply.lower() + " " + msg
            if "emergency" in p_msg or "sos" in p_msg or "critical" in p_msg:
                action, data = "navigate", {"navigate_to": "sos", "urgency": "SOS"}
            elif ("map" in p_msg or "where" in p_msg or "find" in p_msg) and "blood" in p_msg:
                action, data = "search", {"navigate_to": "map", "blood_group": blood_group if blood_group else "O+"}
            elif "ambulance" in p_msg:
                action, data = "navigate", {"navigate_to": "ambulance_tracking"}
            elif "predict" in p_msg or "demand" in p_msg or "analytics" in p_msg:
                action, data = "navigate", {"navigate_to": "demand_prediction"}
                
            return ChatResponse(
                reply=parsed_reply,
                suggestions=["Find blood", "Emergency help", "Donation guide", "View analytics"],
                action_type=action,
                action_data=data if data else None
            )
        except Exception as e:
            print(f"Gemini generation failed: {e}. Falling back to default pattern rules.")
            
    # --- Fallback Pattern matching AI chat logic ---
    # Blood availability queries
    if any(kw in msg for kw in ["find", "where", "locate", "available", "need", "search", "get"]) and any(bg.lower() in msg for bg in ["o+", "o-", "a+", "a-", "b+", "b-", "ab+", "ab-"]):
        bg = next((bg for bg in ["AB+", "AB-", "O+", "O-", "A+", "A-", "B+", "B-"] if bg.lower() in msg), "O+")
        return ChatResponse(
            reply=f"🔍 I'll help you find **{bg}** blood!\n\n"
                  f"Here's what I recommend:\n"
                  f"1. **Check nearby blood banks** — I can show you the closest ones on the map\n"
                  f"2. **Active donors** with {bg} in your area are being notified\n"
                  f"3. **Create an emergency request** to broadcast to all compatible donors\n\n"
                  f"💡 Compatible donors who can donate to {bg}: {', '.join(get_compatible_donors(bg))}",
            suggestions=["Show nearest blood banks", f"Create {bg} request", "Show donor map", "Call emergency helpline"],
            action_type="search",
            action_data={"blood_group": bg, "navigate_to": "map"},
        )

    # Emergency queries
    if any(kw in msg for kw in ["emergency", "urgent", "sos", "critical", "accident", "help", "dying"]):
        return ChatResponse(
            reply="🚨 **EMERGENCY DETECTED!**\n\n"
                  "I'm activating emergency protocols:\n\n"
                  "1. 🆘 **Send SOS** — Tap the SOS button to broadcast to ALL nearby donors\n"
                  "2. 📞 **Call Ambulance** — Emergency services: 108 / 102\n"
                  "3. 🏥 **Nearest Hospital** — I can show you the closest matching hospital\n"
                  "4. 🩸 **Blood Banks** — Checking stock availability now\n\n"
                  "⏱️ Every second counts. Which action should I take?",
            suggestions=["Send SOS now", "Call 108 Ambulance", "Find nearest hospital", "Check blood bank stock"],
            action_type="navigate",
            action_data={"navigate_to": "sos", "urgency": "SOS"},
        )

    # Donation eligibility queries
    if any(kw in msg for kw in ["can i donate", "eligible", "eligibility", "donation", "how to donate", "rules"]):
        return ChatResponse(
            reply="🩸 **Blood Donation Eligibility Guide:**\n\n"
                  "✅ **You CAN donate if:**\n"
                  "• Age: 18-65 years\n"
                  "• Weight: Above 45 kg\n"
                  "• Hemoglobin: Above 12.5 g/dL\n"
                  "• Last donation: 56+ days ago\n"
                  "• No infections in last 2 weeks\n\n"
                  "❌ **You CANNOT donate if:**\n"
                  "• Pregnant or nursing\n"
                  "• Had surgery in last 6 months\n"
                  "• Currently on antibiotics\n"
                  "• HIV/Hepatitis positive\n"
                  "• Heavily tattooed (within 6 months)\n\n"
                  "💡 One donation saves up to **3 lives!**",
            suggestions=["Check my eligibility", "Schedule donation", "Find donation center", "Blood group compatibility"],
            action_type="info",
        )

    # Blood group compatibility
    if any(kw in msg for kw in ["compatible", "compatibility", "match", "who can", "donate to", "receive from"]):
        if blood_group:
            can_donate_to = BLOOD_COMPAT.get(blood_group, [])
            can_receive_from = get_compatible_donors(blood_group)
            return ChatResponse(
                reply=f"🧬 **Blood Compatibility for {blood_group}:**\n\n"
                      f"💉 **You can donate to:** {', '.join(can_donate_to)}\n"
                      f"🩸 **You can receive from:** {', '.join(can_receive_from)}\n\n"
                      f"{'🌟 You are a **Universal Donor!**' if blood_group == 'O-' else ''}"
                      f"{'🌟 You are a **Universal Recipient!**' if blood_group == 'AB+' else ''}",
                suggestions=["Find compatible donors", "Create blood request", "View donation history"],
                action_type="info",
            )
        else:
            return ChatResponse(
                reply="🧬 **Blood Compatibility Chart:**\n\n"
                      "🔴 **O-** → Universal Donor (donates to all)\n"
                      "🔵 **AB+** → Universal Recipient (receives from all)\n"
                      "🩸 **O+** → Most common, donates to O+, A+, B+, AB+\n"
                      "🩸 **A+** → Donates to A+, AB+\n"
                      "🩸 **B+** → Donates to B+, AB+\n\n"
                      "Set your blood group in your profile for personalized info!",
                suggestions=["Set my blood group", "Learn about O-", "Learn about AB+"],
                action_type="info",
            )

    # Ambulance queries
    if any(kw in msg for kw in ["ambulance", "transport", "pickup", "ride"]):
        return ChatResponse(
            reply="🚑 **Ambulance Services:**\n\n"
                  "1. **Track Your Ambulance** — Real-time GPS tracking available\n"
                  "2. **Call Ambulance** — Dial 108 (Government) or 102 (Emergency)\n"
                  "3. **Auto-Assigned** — Our AI automatically assigns the nearest ambulance\n"
                  "4. **ETA** — Estimated arrival time shown on tracking screen\n\n"
                  "📍 Want me to find the nearest ambulance?",
            suggestions=["Track ambulance", "Call 108", "Call 102", "Find nearest ambulance"],
            action_type="navigate",
            action_data={"navigate_to": "ambulance_tracking"},
        )

    # Blood bank queries
    if any(kw in msg for kw in ["blood bank", "bank", "inventory", "stock", "supply"]):
        return ChatResponse(
            reply="🏦 **Blood Bank Information:**\n\n"
                  "1. **View Nearby Blood Banks** — Shown on the map with stock levels\n"
                  "2. **Check Inventory** — Real-time stock data for each blood group\n"
                  "3. **Contact Directly** — Call or visit the nearest blood bank\n\n"
                  "💡 Tip: Blood banks marked '🟢 Active' have verified stock available.",
            suggestions=["Show blood banks on map", "Check stock levels", "Contact nearest bank"],
            action_type="navigate",
            action_data={"navigate_to": "map"},
        )

    # Health/wearable queries
    if any(kw in msg for kw in ["health", "vitals", "heart", "pulse", "wearable", "watch", "fitness"]):
        return ChatResponse(
            reply="⌚ **Health & Wearable Integration:**\n\n"
                  "BloodLink AI can connect with your health data:\n\n"
                  "📊 **Tracked Metrics:**\n"
                  "• Heart Rate — Normal: 60-100 BPM\n"
                  "• Blood Pressure — Normal: ≤120/80\n"
                  "• SpO2 — Normal: 95-100%\n"
                  "• Hemoglobin — Eligible: ≥12.5 g/dL\n\n"
                  "🏥 Before donating, ensure your vitals are in the safe range.\n\n"
                  "💡 Share your health report with the blood bank for faster processing!",
            suggestions=["Check my eligibility", "View health tips", "Connect wearable"],
            action_type="info",
        )

    # Statistics/analytics queries
    if any(kw in msg for kw in ["stats", "statistics", "analytics", "report", "data", "how many"]):
        return ChatResponse(
            reply="📊 **BloodLink AI Analytics:**\n\n"
                  "I can show you:\n"
                  "• 📈 **Demand Predictions** — Which blood groups will be needed\n"
                  "• 🗺️ **Donor Distribution** — Where donors are located\n"
                  "• ⏱️ **Response Times** — Average time to fulfill requests\n"
                  "• 🩸 **Most Requested** — Blood groups in highest demand\n\n"
                  "Want to see the AI Blood Demand Prediction dashboard?",
            suggestions=["Show demand predictions", "View donor stats", "Response time report"],
            action_type="navigate",
            action_data={"navigate_to": "demand_prediction"},
        )

    # Greeting
    if any(kw in msg for kw in ["hello", "hi", "hey", "good", "help", "start"]):
        role_specific = {
            "donor": "As a donor, you can check incoming requests, track your donation history, and get notified for emergencies.",
            "hospital": "As a hospital, you can create blood requests, track donors, manage SOS alerts, and monitor blood bank inventory.",
            "blood_bank": "As a blood bank, you can manage inventory, respond to requests, and coordinate with hospitals.",
            "admin": "As an admin, you have full oversight of the network with analytics and fraud detection.",
        }
        return ChatResponse(
            reply=f"👋 **Hello! I'm BloodLink AI Assistant.**\n\n"
                  f"I'm here to help you with:\n"
                  f"🩸 Finding blood donors & banks\n"
                  f"🚑 Emergency response coordination\n"
                  f"📊 Blood demand predictions\n"
                  f"💬 Any blood donation questions\n\n"
                  f"📌 {role_specific.get(role, role_specific['donor'])}\n\n"
                  f"How can I help you today?",
            suggestions=["Find blood", "Emergency help", "Donation guide", "View analytics"],
            action_type="info",
        )

    # Default fallback
    return ChatResponse(
        reply=f"🤖 I understand you're asking about: *\"{request.message}\"*\n\n"
              f"Here's what I can help with:\n\n"
              f"🩸 **Blood Search** — \"Find O+ blood near me\"\n"
              f"🚨 **Emergency** — \"I need urgent help\"\n"
              f"📋 **Eligibility** — \"Can I donate blood?\"\n"
              f"🧬 **Compatibility** — \"Who can donate to A+?\"\n"
              f"🚑 **Ambulance** — \"Track my ambulance\"\n"
              f"📊 **Analytics** — \"Show demand predictions\"\n\n"
              f"Try asking me something specific!",
        suggestions=["Find blood near me", "Emergency help", "Check eligibility", "Blood compatibility"],
        action_type="info",
    )


# --------------- 5. Fraud Prevention ---------------
@app.post("/api/fraud_check", response_model=FraudCheckResult)
async def fraud_check(request: FraudCheckInput, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    score = 0.0
    flags = []

    # Check donation frequency (can't donate more than once every 56 days)
    if request.action == "donate" and request.donation_count_30d >= 1:
        score += 40
        flags.append("Multiple donations within 30 days — possible fake donor")

    # Check request frequency
    if request.action == "request" and request.request_count_24h > 5:
        score += 35
        flags.append(f"Excessive requests: {request.request_count_24h} in 24h — potential abuse")
    elif request.action == "request" and request.request_count_24h > 3:
        score += 20
        flags.append(f"High request frequency: {request.request_count_24h} in 24h")

    # Account age
    if request.account_age_days < 1:
        score += 25
        flags.append("Brand new account — insufficient trust history")
    elif request.account_age_days < 7:
        score += 15
        flags.append("Account less than a week old")

    # Location anomalies
    if request.location_changes_24h > 10:
        score += 25
        flags.append(f"Suspicious location changes: {request.location_changes_24h} in 24h")
    elif request.location_changes_24h > 5:
        score += 10
        flags.append(f"Frequent location changes: {request.location_changes_24h} in 24h")

    # Previous rejections
    if request.previous_rejections > 5:
        score += 20
        flags.append(f"History of {request.previous_rejections} rejections — reliability concern")
    elif request.previous_rejections > 2:
        score += 10
        flags.append(f"{request.previous_rejections} previous rejections")

    # Determine risk level
    score = min(score, 100)
    if score >= 70:
        risk_level = "critical"
        recommendation = "BLOCK — Account flagged for immediate review. Do not process this request."
    elif score >= 45:
        risk_level = "high"
        recommendation = "MANUAL REVIEW — Requires admin verification before proceeding."
    elif score >= 20:
        risk_level = "medium"
        recommendation = "MONITOR — Allow with increased monitoring. Flag for weekly review."
    else:
        risk_level = "low"
        recommendation = "APPROVED — No suspicious activity detected."

    if not flags:
        flags.append("No suspicious indicators found")

    return FraudCheckResult(
        is_suspicious=score >= 45,
        risk_score=round(score, 1),
        risk_level=risk_level,
        flags=flags,
        recommendation=recommendation,
    )


# --------------- 6. Ambulance Auto-Assignment ---------------
@app.post("/api/assign_ambulance", response_model=AmbulanceAssignResult)
async def assign_ambulance(request: AmbulanceAssignInput, x_api_key: Optional[str] = Header(None)):
    if x_api_key and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

    available = [a for a in request.ambulances if a.is_available]
    if not available:
        raise HTTPException(status_code=404, detail="No ambulances available")

    best = None
    best_score = -1

    urgency_speed = {"SOS": 60, "Critical": 50, "Urgent": 40, "Normal": 30}
    avg_speed = urgency_speed.get(request.urgency, 30)

    for amb in available:
        # Distance to request location
        dist_to_request = haversine(amb.lat, amb.lng, request.request_location.lat, request.request_location.lng)
        # Distance from request to hospital
        dist_to_hospital = haversine(request.request_location.lat, request.request_location.lng,
                                     request.hospital_location.lat, request.hospital_location.lng)

        total_dist = dist_to_request + dist_to_hospital
        eta = (dist_to_request / avg_speed) * 60  # minutes

        # Score: closer is better, vehicle type matters
        score = 100 - (dist_to_request * 3)  # Distance penalty
        if amb.vehicle_type == "mobile_icu":
            score += 20
        elif amb.vehicle_type == "advanced":
            score += 10

        # Urgency bonus for closer ambulances
        if request.urgency in ["SOS", "Critical"] and dist_to_request < 5:
            score += 15

        reasons = []
        reasons.append(f"Distance: {dist_to_request:.1f}km to pickup")
        reasons.append(f"Total route: {total_dist:.1f}km")
        reasons.append(f"ETA: {max(1, round(eta))} min @ {avg_speed}km/h")
        reasons.append(f"Vehicle: {amb.vehicle_type}")

        if best is None or score > best_score:
            best = amb
            best_score = score
            best_dist = dist_to_request
            best_eta = max(1, round(eta))
            best_reasoning = " | ".join(reasons)

    return AmbulanceAssignResult(
        ambulance_id=best.id,
        distance_km=round(best_dist, 2),
        eta_minutes=best_eta,
        route_score=round(best_score, 2),
        reasoning=best_reasoning,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
