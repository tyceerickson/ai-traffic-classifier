# Local ML vs Cloud AI — Deployment Architecture Comparison

*Written after completing Milestones 0–7: lab infrastructure, data collection,
model training, and Ollama explainability layer.*

---

## Introduction

Network intrusion detection is a problem that never sleeps. Every organization
connected to the internet generates thousands of network flows per minute, and
somewhere in that traffic, attacks are happening. The question facing security
engineers is not just "can we detect them" but "how do we build a system that
detects them reliably, quickly, and without introducing new risks in the
process."

This project builds an end-to-end network traffic classifier trained on real
attack and benign traffic generated in a physically segmented home lab. The
classifier identifies malicious flows with 99.99% accuracy across eight
distinct attack scenarios — port scanning, service fingerprinting, credential
brute force, denial of service, C2 beaconing, IDS evasion, and remote
exploitation.

But building a working model raises a second question: how would you actually
deploy it? This writeup compares two fundamentally different approaches to
that question, a fully local ML deployment versus a cloud AI API approach,
and examines the tradeoffs that matter in real security environments.

---

## The Local ML Approach

### Architecture

The local approach runs entirely within the network it protects. In this
project that means:

- **OPNsense firewall** captures all traffic between attacker and victim VLANs
  continuously, writing PCAPs to local storage
- **Suricata IDS** runs offline on a local Ubuntu Server, analyzing PCAPs with
  50,165 ET Open rules to generate alert metadata
- **CICFlowMeter** extracts 78 statistical features from each network flow —
  packet counts, inter-arrival times, flag distributions, byte ratios — and
  outputs a structured CSV
- **Random Forest classifier** trained on 610,137 labeled flows makes
  malicious/benign predictions in milliseconds
- **Ollama llama3.1:8b** running on a local RTX 4070 provides plain-English
  explanations of flagged flows, no data leaves the machine

Every component runs on hardware the operator controls. No data traverses the
internet. No external service has visibility into the network traffic being
analyzed.

### Why Local First

**Privacy is the primary argument.** Network traffic is among the most
sensitive data an organization holds. It contains authentication credentials,
internal hostnames, business communication patterns, and potential evidence of
ongoing incidents. Sending this data to a cloud API, even an encrypted one,
means trusting a third party with information that could expose the
organization if mishandled, subpoenaed, or breached.

In regulated industries this is not a philosophical concern. Healthcare
organizations subject to HIPAA, financial institutions subject to SOX, and
government contractors subject to FedRAMP often have explicit prohibitions on
sending network telemetry to external services. A local deployment sidesteps
this entirely.

**Latency matters for detection.** A cloud API round-trip adds 50–500ms of
latency per inference request. For bulk offline analysis this is acceptable.
For real-time alerting during an active intrusion, every second of delay is
operational dwell time for the attacker. The local Random Forest model in this
project classifies a flow in under 1 millisecond on the Alienware workstation.
There is no network hop, no API rate limit, no service degradation during a
high-volume attack.

**Cost at scale is non-trivial.** Cloud AI APIs charge per token or per
request. This project analyzed 1,201,560 network flows from a single 5-hour
capture session. At even modest per-request pricing, classifying production
network traffic at enterprise scale, millions of flows per hour, would
generate significant ongoing API costs. The local model runs for free after
the initial hardware investment.

**Explainability without data exposure.** This project uses Ollama to generate
plain-English explanations of flagged flows. A security analyst seeing "ET SCAN
Suspicious inbound to MySQL port 3306" in a Suricata alert may not immediately
understand the full context. The LLM explanation, running entirely locally on
an RTX 4070, translates the raw feature values into actionable language:
"This flow shows a single SYN packet to port 3306 with no corresponding ACK,
consistent with a port scan probing for exposed database services." The analyst
gets context without the flow data ever leaving the building.

### Limitations of the Local Approach

**Hardware constraints are real.** Training the Random Forest on 610,137 flows
took seconds on an an Alienware m16 R2 with a 16-core / 22-thread Intel Ultra 9 185H and 64GB RAM. On a
modest server or edge device, the same workload could take hours. Organizations
without capable local infrastructure face a difficult tradeoff between
detection capability and hardware budget.

**Model freshness requires operational discipline.** A cloud AI service updates
its models continuously. A local model reflects the threat landscape at the
time it was trained. New attack techniques — novel malware, zero-days, living-
off-the-land techniques that blend with legitimate traffic — will not be
detected by a model that has never seen them. Regular retraining against fresh
capture sessions is essential but requires ongoing operational commitment.

**The lab-to-production gap.** This model was trained entirely on traffic from
a controlled lab environment with distinctive attack patterns. Real production
networks have vastly more traffic diversity — legitimate port scanners, network
monitoring tools, cloud service probes, misconfigured applications — that can
generate false positives. The 99.99% accuracy achieved in this project would
likely not hold on an unseen network without domain-specific retraining.

---

## The Cloud AI API Approach

### What It Would Look Like

A cloud-based approach to this problem would look significantly different. Instead
of a locally trained classifier, the operator would send network flow features
to an external API — either a general-purpose model fine-tuned for security,
a purpose-built network security API, or a foundation model prompted to
classify traffic.

In practice this might involve:

- Extracting CICFlowMeter features locally (this step stays on-premises for
  performance reasons)
- Sending batches of flow feature vectors to a classification API
- Receiving malicious/benign predictions with confidence scores
- Optionally using a large language model API to generate analyst-facing
  explanations

Several services offer this capability today, including security-specific APIs
from vendors like Darktrace and Vectra, and general-purpose ML APIs that can be
fine-tuned on labeled flow data.

### Advantages of Cloud AI

**No training infrastructure required.** The most significant operational
advantage of a cloud approach is eliminating the need to maintain training
infrastructure. The cloud provider handles model versioning, retraining,
hardware scaling, and availability. A small security team without dedicated
ML engineering resources can consume a high-quality classifier without building
one.

**Automatic model updates.** Cloud security AI vendors update their models
continuously against global threat intelligence feeds. A locally trained model
trained on eight attack scenarios in a home lab will not detect novel malware
families. A cloud model trained on telemetry from thousands of enterprise
customers has seen vastly more attack variety.

**Scalability without hardware investment.** A cloud API scales horizontally
with demand. During a DDoS or large-scale network intrusion — precisely when
local compute may be under pressure — the cloud classification service remains
unaffected. Local inference on a single workstation has a ceiling.

### Disadvantages of Cloud AI

**Data privacy and regulatory exposure.** As discussed above, sending network
traffic to an external service introduces privacy risk and potential regulatory
violations. Even with encryption in transit and contractual data handling
guarantees, the data leaves organizational control.

**Vendor dependency and availability risk.** A local model runs regardless of
internet connectivity, API service status, or vendor business decisions. A
cloud dependency means that an outage in the classification service — or a
vendor going out of business, changing pricing, or deprecating an API version —
directly impacts detection capability.

**Latency for real-time use cases.** Network round-trip latency makes cloud
APIs unsuitable for inline, real-time blocking decisions. They are better suited
to asynchronous analysis — flagging flows after the fact rather than blocking
them in flight.

**Black box opacity.** General-purpose cloud AI APIs often provide minimal
transparency about how classifications are made. Security teams cannot audit
the model, understand its failure modes, or explain its decisions to
stakeholders. This is a significant problem in regulated environments where
audit trails and explainability are required.

---

## Comparison Table

| Dimension | Local ML (this project) | Cloud AI API |
|-----------|------------------------|--------------|
| **Data privacy** | All data stays on-premises | Data sent to external service |
| **Regulatory compliance** | Suitable for HIPAA, FedRAMP, SOX | Requires vendor DPA review |
| **Inference latency** | <1ms (local RAM/CPU) | 50–500ms (network round-trip) |
| **Cost at scale** | Fixed hardware cost | Per-request pricing |
| **Model freshness** | Manual retraining required | Automatic vendor updates |
| **Threat coverage** | Limited to training scenarios | Trained on global telemetry |
| **Explainability** | Full — local Ollama LLM | Varies — often opaque |
| **Infrastructure burden** | High — training + serving | Low — API consumption only |
| **Availability** | Independent of internet | Dependent on vendor uptime |
| **Customization** | Full control over features/labels | Limited to vendor API surface |
| **Auditability** | Complete — open source stack | Limited — vendor black box |

---

## Recommendation for Real-World Deployment

Neither approach is universally correct. The right choice depends on the
organization's threat model, regulatory environment, and operational maturity.

**Choose local ML when:**
- The organization handles regulated data (healthcare, finance, government)
- Network traffic contains sensitive information that cannot leave the perimeter
- Real-time inline detection is required
- The security team has ML engineering capability for ongoing model maintenance
- The organization wants full auditability and explainability of detections

**Choose cloud AI when:**
- The organization lacks ML training infrastructure or expertise
- Threat coverage breadth is more important than data privacy
- The use case is asynchronous (post-hoc analysis, not real-time blocking)
- The organization can accept vendor dependency and its associated risks

**The hybrid approach is often optimal in practice.** Run a local model for
real-time, privacy-sensitive classification of internal traffic. Use a cloud
service for threat intelligence enrichment — looking up flagged IPs and domains
against external feeds — without sending raw flow data externally. This captures
most of the benefit of both approaches while managing the tradeoffs of each.

---

## Conclusion

This project demonstrates that a high-quality network intrusion detection
classifier can be built entirely from local infrastructure, open-source tools,
and real-world generated data. The Random Forest classifier achieves 99.99%
accuracy with a 1.0 F1 score across eight attack scenarios, trained on 1.2
million labeled network flows from a physically segmented lab environment.

The local deployment approach — with Suricata for signature-based detection,
CICFlowMeter for feature extraction, Random Forest for classification, and
Ollama for explainability — provides a complete, privacy-preserving, low-latency
detection pipeline that costs nothing to operate beyond the initial hardware.

The cloud AI approach offers real advantages in threat coverage, operational
simplicity, and scalability that cannot be dismissed. For organizations without
dedicated ML capability, a well-chosen cloud security AI service may deliver
better real-world detection than a locally trained model that lags the threat
landscape.

The most important insight from building this project is that the choice of
deployment architecture is inseparable from the choice of data. A model is only
as good as what it was trained on. Regardless of where inference runs — locally
or in the cloud — continuous data collection, labeling, and retraining against
real network traffic is the foundational discipline that determines whether a
classifier catches threats or misses them.
