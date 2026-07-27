# Typed Procedural Invariant Induction for Selective Mistake Detection — Idea Report

> 生成时间：2026-07-26 | 状态：PENDING_REVIEW | 目标会议：CVPR
> 三值版（required / witnessed-free / unknown），非早期两值版。

---

## Part 1 Topic Overview

### 1 Motivation

程序性错误检测（procedural mistake detection）近三年被大量占领：任务图路线（DTGL, NeurIPS'24；GTG2Vid, ICCV'25）、预测不一致路线（PREGO, CVPR'24；TI-PREGO；ESTANet）、原型/单类路线（EgoPER, CVPR'24；AMNAR, CVPR'25；PECC）、早退出（MistExit）、归因与解释（MATT, CVPR'26；AXG-Reasoner, CVPR'26；MistSense, ICCV'25）。这些工作在 `脚本化错误 vs 正常` 的评测协议下把 F1/AUC 推到了较高水平。

但这个协议隐藏了一个部署阻断级的失效模式：**没有任何一篇工作在「不寻常但正确」的执行上被压测过**。用户换一把没见过的扳手、换用左手、把两个顺序无关的子动作对调——这些都是合法执行，但对以「不像训练视频」为判据的检测器而言与真错误无法区分。假警报直接摧毁用户信任，而现有指标对此完全不敏感。

这不是推测。EgoPER（CVPR'24）在构造数据时明确把「换工具」列为错误：

> "some steps are modified (e.g., **using a different tool** or different ingredients from the ones specified by the recipe)" (Sec. 3.1)

同时它的正常视频只在 **step 顺序**上变化：

> "the sequence of steps is consistent with the task graph (although each video can have a different sequence from others) and **the execution of each step follows the specific description of the step**" (Sec. 3.1)

两句话合起来说明：step 内部的非典型执行按构造就没有被采样进 normal 集，而一旦出现就被判为错误。领域综述（Bacharidis & Argyros, CVIU 2026 / arXiv:2510.19292）独立地把这件事列为 open challenge——「区分可容许变异与真实错误」以及「模型缺乏对任务目标与程序约束的显式表示，因而误分类罕见但正确的行为」。

**本研究的必要性：**

- **应用必要性**：AR 助手、工业质检、技能训练三类落地场景中，误报成本与漏报成本不对称——漏报只是错过一次提醒，误报会让用户关闭系统。当前无任何方法给出误报的可控性。[EgoPER][survey]
- **理论必要性**：正例学习的可学习性边界在形式化方法中已有结论（Chou & Berenson 2018：从安全示范只能确立约束的一个子集），但 procedural video 领域仍在用「像/不像」的二元判据，把认识论上不可判定的情况强行二分。
- **时机必要性**：属性级感知（语义角色、物体状态、手物交互）在 2024–2026 已趋成熟（MATT 的 role 归因、MOSCATO 的多物体状态、Grounding DINO 类开放词表检测），使「把 step 分解成可验证属性」第一次具备可行性。

> 直白补充：现在这个领域比的是谁在同一套受污染的评测集上多 2 个点。本文换一个轴——在保持错误召回的前提下，谁对合法变异更宽容，且能说清为什么。

### 2 Research Questions

以下 RQ 从 Section 1 的两个 gap 推导：(g1) 评测协议从未包含合法变异；(g2) 现有方法输出分数而非可检验的约束，且被迫对认识论上不可判定的属性做二分。

#### 主要研究问题（Primary RQ）

**RQ1：能否仅从少量正确执行中，归纳出每个 step 的带类型、可读、且显式区分「必要 / 已证自由 / 未知」的规范，并以此把误报限制在真正违反必要约束的情形？**

- **对应 gap**：g1 + g2
- **新颖性**：现有方法在 step-identity 粒度建模「多个合法下一步」（AMNAR），或把执行变异隐式吸收进嵌入簇（EgoPER）。无人在 step 内部把属性分解为三值状态并输出可读约束。（占位判定见 §Part 2 / 2.3）
- **可回答性**：不变量质量可直接对照人工规范评测（precision/recall on required、free 识别率、unknown 校准），不依赖下游 F1。

#### 次要研究问题（Secondary RQs）

**RQ2：在正例数量有限时，模型何时「有资格」声称某属性是必要的？弃权（abstain）能否换来可控的误报下降而非平凡的覆盖率坍缩？**

- **对应 gap**：g2
- **与 RQ1 的关系**：RQ1 问能不能归纳出规范，RQ2 问这个规范的认识论诚实性。若无 RQ2，三值退化成两值，直接落入 Chou & Berenson 的可学习性边界。

**RQ3：显式不变量相比隐式原型，是否带来对未见工具 / 未见执行者 / 未见合法顺序的更好泛化？**

- **对应 gap**：g1
- **与 RQ1 的关系**：检验归纳出的规范是否抓到了任务的本质约束，而非训练集的表面统计。

### 3 Key Works

选取逻辑：按「与本任务的距离」而非按热度。分三类——(a) 最近的竞争者（必须在 related work 里正面处理）；(b) 被本文否定的评测协议来源；(c) 迁移来源（形式化方法侧，必须诚实归属）。

| 简称 | 会议/期刊 | 年份 | 核心贡献（一句话） | 对本研究的借鉴价值 |
|------|----------|------|-----------------|----------------|
| EgoPER | CVPR | 2024 | 单类 + 对比式 step 原型，捕捉无错执行的变异 | 最接近的 setup；也是被本文否定的协议来源 |
| AMNAR | CVPR | 2025 | 预测所有合法下一动作并重建其正常表示 | 「多个正常」的最强 baseline，但在 step-identity 粒度 |
| AXG-Reasoner | CVPR | 2026 | 正例学习动作执行图 + 子动作分解 + VLM 解释 | 输出端最接近（子步骤 + 语言），审稿人会往这里压 |
| GTG2Vid | ICCV | 2025 | 广义任务图 + 错误类型识别（含 modification） | 说明社区已触及类型边界，但仍无 free/unknown |
| MATT | CVPR | 2026 | 语义角色归因 + PNR + 空间定位 | 属性类型词表的先例；但方向相反（从指令出发 + 合成负例） |
| Chou & Berenson | WAFR | 2018 | 从安全示范学习约束，含可学习性边界定理 | **本文认识论论证的真正所有者**，必须诚实归属 |
| Bayesian Spec. Inference | — | 2021 | 从示范推断 LTL 规范 | 「正例轨迹 → 可读规范 + 不确定性」的形式化祖先 |
| PUnS | — | 2019 | 在 LTL 公式的信念分布上规划 | 规范歧义作为一等公民的先例 |
| Mistake Analysis Survey | CVIU | 2026 | 综述；列出可容许变异与错误传播两个 open problem | 本文 gap 陈述的第三方背书 |

#### EgoPER（CVPR 2024）

1. **解决了什么研究问题**：只用正常视频训练，在自建的 EgoPER 数据集上做帧级错误检测。
2. **用了什么方法**：TAS backbone + 主动物体检测的 GCN 关系特征，配合对比式 step 原型学习（每个 step 学 k 个原型），推理时按特征-原型相似度与逐 step 阈值判错。
3. **效果**：EgoPER 上 EDA 57.0 / AUC 62.0。
4. **对本研究的意义**：它是最接近的 setup（正例学习 + 声称捕捉执行变异），但变异只存在于隐式嵌入簇中，从未外化为具名属性；且它把「换工具」标为错误——这正是本文要放行的情形。

> 借鉴价值：作为主要对照与被否定对象。
> 是否关键工作：是，因为它同时提供了最接近的方法设定与最直接的协议反例。

#### AMNAR（CVPR 2025）

一句话：通过任务图 + DP 预测所有合法下一动作，为每个候选重建正常表示，与进行中动作比距离。

> 借鉴价值：核心 baseline。本地全文检索确认：`interpretable`、`human-readable`、`abstain`、`abstention`、`attribute`、`constraint`、`invariant` 七个词出现次数**均为 0**，其「多个合法」严格在 step-identity 粒度（原文例："valid next actions include 'Boil Water' and 'Prepare Filter'"）。
> 是否关键工作：是。

#### AXG-Reasoner（CVPR 2026）

一句话：从无错视频学动作执行图（AXG）+ TAS，把动作段分解成子动作后逐个查询冻结 VLM 做检测与解释。

> 借鉴价值：输出端最接近的工作——同样正例学习、同样走到 step 以下粒度、同样产出语言。差异在于 AXG 是引导 VLM 注意力的结构而非归纳出的规范，解释是检测的事后说明而非挖掘出的约束，且无三值划分与弃权。
> 是否关键工作：是，风险最高的重叠。

#### Chou & Berenson（WAFR 2018）[待核实：确切 venue/年份需再核]

一句话：从安全示范中学习不安全集，并给出「从安全示范只能确立约束的哪个子集」的可学习性结论。

> 借鉴价值：**本文 `unknown` 类别的认识论依据已被这篇论文在轨迹优化设定下拥有**。本文能声称的是 video/属性层面的实例化与三值化操作，不是这个洞察本身。写作时必须显式让渡。
> 是否关键工作：是。

---

## Part 2 Idea Design

### 1 Introduction

一个能用的程序助手必须区分三件事：用户做错了、用户用了一种它没见过但合法的做法、以及它没有足够依据下判断。当前的错误检测器只会做第一件事，并把后两件都归入第一件。

本文提出**类型化程序不变量归纳（Typed Procedural Invariant Induction）**：给定某个 step 的少量正确执行视频，归纳出该 step 的显式规范，把属性划入三个互斥集合——`required`（在所有正确示范中稳定成立，且有依据认为必要）、`witnessed-free`（在正确示范之间已被观察到发生变化，因而证明可自由变动）、`unknown`（在示范中从未变化，因而无法确立其必要性）。检测时：违反 `required` 报警；仅改变 `witnessed-free` 放行；触及 `unknown` 弃权。

`unknown` 是本文与「把规范挖掘搬到视频」之间的分界线。只有 required/free 两值时，一个在三个示范里始终是勺子的 instrument 必须被判成必要或自由，两种判断都可能错——这正是 Chou & Berenson (2018) 在轨迹优化设定下证明的正例学习边界。三值化把这个边界变成模型的显式输出，而不是一个静默的错误。

贡献如下：
- **方法层面**：提出 positive-only 条件下的类型化程序不变量归纳任务，形式化为三值规范 $\Phi_s = (\Phi_s^{req}, \Phi_s^{free}, \Phi_s^{unk})$，并给出保守归纳算子与其单调性性质。
- **技术层面**：类型层级上的抽象搜索（学「需要有扭矩能力的工具」而非「必须是那把扳手」）+ MDL 正则化避免琐碎规则 + 基于弃权的选择性检测。
- **实验层面**：提出 hard-normal 评测轴，报告 error recall vs hard-normal FAR 曲线、弃权率-召回曲线（含 always-abstain 平凡基线）、以及示范数量消融。（占位，完成实验后填真实数据）

### 2 Related Works

#### 2.1 程序性错误检测

任务图路线把正确性归约为偏序满足（DTGL, GTG2Vid），因而无法表达重复次数上界、互斥、紧邻后继等约束。预测不一致路线（PREGO/TI-PREGO/ESTANet）以「识别与预测不符」为判据，其单步预测隐含唯一正确顺序的假设，PREGO 自己承认「多个合理流程」未解决。原型/单类路线（EgoPER, AMNAR, PECC）用距离阈值判错，变异被吸收进嵌入而非显式表示。

> 共同点：输出是分数，判据是「像不像」，而合法变异与真错误在这个判据下不可分。

#### 2.2 从示范中学习规范

形式化方法侧有成熟的两条线：从正例轨迹推断时序逻辑规范（Bayesian Specification Inference；PUnS 在公式信念分布上规划），以及从示范学习约束并刻画可学习性边界（Chou & Berenson 及后续）。语义约束在 Learning-from-Observation 中也有类型化词表的先例。

> 这两条线在 procedural video 上基本无占位——本地检索显示 `"specification mining" AND video` 在 arXiv 上仅 1 条命中且为机器人规划论文，说明该词对在视觉社区几乎未被使用。这既是机会，也意味着检索上的「看起来新」不等于实质新，必须靠机制而非术语立论。

#### 2.3 研究空白

无任何工作从 positive-only 视频归纳出类型化、可读、三值划分的 step 内规范，也无任何工作在认识论无依据的属性上弃权。每个组件在别处都有先例（AMNAR 的多正常、AXG-Reasoner 的子步骤+语言、MATT 的角色类型、Chou & Berenson 的可学习性），但组合与评测轴是空的。

同时，**未能找到任何工作以「合法但非典型执行」为测试集评测错误检测器**。需要标注置信度：这是 absence of results 而非 proven vacant——本轮 Semantic Scholar 全程 429 无覆盖，arXiv API 中途限流产生过已确认的假阴性。该结论置信度为中高。

> 一句话：现有方法卡在「把不像当成错」，本文从「先说清什么必须成立、什么可以变、什么还不知道」突破。

### 3 Method

#### 3.1 形式化定义

**属性类型词表.** 定义类型集合 $\mathcal{T} = \{$ Predicate, Object, Instrument, State, Spatial, Temporal, Manner, Actor $\}$。对 step $s$ 的一次执行 $v$，感知前端产出结构化轨迹

$$
\pi(v) = \langle a_1, \dots, a_K \rangle, \quad a_k = \big(\tau_k,\; \text{val}_k\big),\ \tau_k \in \mathcal{T}
$$

即一组带类型的属性-取值对（含动作前后的状态变化）。

**三值规范.** 给定同一 step 的正确示范集合 $D^+_s = \{v_1,\dots,v_N\}$，本任务的输出为

$$
\Phi_s = \big(\Phi_s^{req},\ \Phi_s^{free},\ \Phi_s^{unk}\big)
$$

三者对属性槽位构成划分。设 $\text{Val}(\tau \mid D^+_s)$ 为属性 $\tau$ 在示范集上的取值多重集，$|\cdot|_{\ne}$ 记不同取值个数：

$$
\tau \in \Phi_s^{free} \iff |\text{Val}(\tau \mid D^+_s)|_{\ne} \ge 2
$$

$$
\tau \in \Phi_s^{req} \iff |\text{Val}(\tau \mid D^+_s)|_{\ne} = 1 \ \wedge\ \text{Nec}(\tau) \ge \theta
$$

$$
\tau \in \Phi_s^{unk} \iff |\text{Val}(\tau \mid D^+_s)|_{\ne} = 1 \ \wedge\ \text{Nec}(\tau) < \theta
$$

> 公式含义：**只有观察到变化才能证明自由**（$\Phi^{free}$ 由证据直接给出，这是唯一无需外部知识的判定）；恒定属性则需要额外的必要性证据 $\text{Nec}(\tau)$ 才能升为 `required`，否则诚实地留在 `unknown`。

**必要性证据 $\text{Nec}$.** 恒定不足以证明必要（三个示范都用勺子，不代表必须用勺子）。$\text{Nec}$ 由三个来源加权：
1. **因果耦合**：该属性是否出现在 step 的目标状态谓词的因果闭包中（例如 `nut.tightened` 是 step 的完成条件，则决定它的属性必要性升高）；
2. **跨 step 一致性**：该属性在其他 step 的对应槽位上是否也恒定（普遍恒定 → 更可能是采集偏置而非必要）；
3. **语言先验**：step 文本是否显式约束该槽位（"tighten with a wrench" vs "tighten"）。

> 设计依据：单纯的统计恒定性无法与采集偏置区分，必须引入与任务目标的因果联系。EgoPER 在采集时随机改变桌面物体与光照正是为了打掉这类偏置（Sec. 3.1），说明社区已意识到该问题，但未把它做进判据。

**类型层级上的抽象.** 每个属性取值挂在一个类型层级 $\mathcal{H}$ 上（`electric_wrench` ⊏ `wrench` ⊏ `torque-capable-tool`）。归纳时在层级上搜索**能覆盖全部正确示范的最一般（最抽象）节点**：

$$
\hat{h}(\tau) = \arg\max_{h \in \mathcal{H}} \ \text{generality}(h) \quad \text{s.t.} \quad \forall v \in D^+_s,\ \text{val}_\tau(v) \sqsubseteq h
$$

> 这是本文避免过拟合 few-shot 的主要装置：宁可学出「需要有扭矩能力的工具」，也不学「必须是这把电动扳手」。与 version space 的最一般边界（G-set）同构，是必须引用的经典。

**MDL 正则.** 在候选规范集合上以描述长度惩罚规则数量与特化程度，抑制只对训练样本成立的琐碎规则：$\Phi_s^* = \arg\min_\Phi\ L(\Phi) + L(D^+_s \mid \Phi)$。

**选择性检测.** 测试执行 $v'$ 的判定：

$$
\text{Decide}(v') = \begin{cases}
\text{Alarm} & \exists \tau \in \Phi_s^{req}: \text{val}_\tau(v') \not\sqsubseteq \hat h(\tau) \\
\text{Abstain} & \text{否则若 } \exists \tau \in \Phi_s^{unk}: \text{val}_\tau(v') \not\sqsubseteq \hat h(\tau) \\
\text{Pass} & \text{否则}
\end{cases}
$$

输出附带违反的具体不变量、观测值与证据帧区间。

#### 3.2 方法流程

```text
少量正确视频 → [感知前端：step分割/物体跟踪/状态变化] → 类型化属性轨迹
              → [候选不变量生成 + 类型层级抽象] → 候选集
              → [保守归纳算子 + Nec 评分 + MDL] → 三值规范 Φ_s
测试视频      → [同一前端] → [规范验证器] → Alarm / Pass / Abstain + 可读理由
```

> 数据流说明：符号层是瓶颈也是卖点。感知前端用冻结模型（开放词表检测 + 状态识别 + 7B VLM 属性读取），仅归纳算子与验证器是本文训练/设计的部分。

#### 3.3 感知前端的风险与降级方案

这是本方案最大的技术风险。corpus 内的前车之鉴不乐观：Action Effect Modeling（ICLR'26）报告 GPT-4o 在 effect frame 上的场景识别成功率仅 **48.4%**；A.I.R.（ICLR'26）明确指出计数与 OCR 是其失败模式。若属性抽取精度在 50% 量级，归纳出的不变量即为噪声。

**降级方案（按优先级）**：
1. 收窄类型词表至可靠维度（Object / Instrument / Actor 相对可靠；Manner / 精细 Spatial 不可靠）；
2. 对不可靠维度整体归入 `unknown`，让弃权机制吸收感知不确定性——这与本文的认识论立场一致，是自洽的降级而非补丁；
3. 在 oracle-attribute 设定下额外报一组结果，把「归纳算子的能力」与「感知的能力」解耦（对照 MistExit 的 oracle 协议做法）。

#### 3.x Baseline 与评价指标

| Baseline | 来源 | 选择理由 |
|---------|---------|---------|
| EgoPER | Lee & Elhamifar, CVPR 2024 | 同为 positive-only；最直接的隐式变异建模对照 |
| AMNAR | Huang et al., CVPR 2025 | 「多个正常」的最强对照，step-identity 粒度 |
| AXG-Reasoner | Lee & Elhamifar, CVPR 2026 | 输出端最接近（正例 + 子步骤 + 语言） |
| ESTANet | — | 在线预测不一致路线代表，效率友好 |
| Zero-shot VLM | ZeProM 类 | 无需训练的强对照，防止「小模型打小模型」 |
| always-abstain | 本文构造 | **平凡基线，必须画在弃权曲线上** |
| w/o unknown（两值消融） | 本文构造 | 直接检验三值化的必要性 |

| 评价指标 | 定义 | 选择依据 |
|---------|------|------------|
| Hard-normal FAR | 合法非典型执行上的误报率 | 本文的核心主张 |
| Error Recall @ matched FAR | 固定误报率下的真错误召回 | 防止用召回换误报 |
| Required precision/recall | 归纳出的 required 集合对照人工规范 | 直接评测不变量质量（不依赖下游） |
| Free identification rate | 正确识别出的自由属性比例 | 同上 |
| Unknown calibration | `unknown` 中事后被证明为必要的比例 | 检验认识论诚实性 |
| Coverage / abstention rate | 非弃权样本比例 | 与上面所有指标联合报告，防止覆盖率坍缩 |
| Selective risk | 弃权后剩余样本的风险 | selective prediction 标准指标 |

> 关键：**任何指标都不得单独汇报，必须与 coverage 成对出现**。这是防御「用弃权换漂亮数字」的唯一方式。

---

## Part 3 Experiment Design

### 0 实验 #0：动机验证（决定项目是否继续）

**这是第一个要做的实验，在方法实现之前。**

**目的**：证明现有 SOTA 在 hard normals 上确实误报。若误报率不高，本文无问题可解，应立即止损。

**做法**：取 AMNAR（代码：`github.com/iSEE-Laboratory/AMNAR`）与 EgoPER 的公开实现，在构造好的 hard-normal 集上直接推理，记录 FAR。

**期望**：FAR 显著高于其在标准 normal 集上的水平。若成立，Figure 1 就是**用别人的方法**演示出来的失效，而非自我断言——这是全文最有说服力的一张图。

**止损线**：若两者 hard-normal FAR 与常规 normal FAR 无显著差异，本 idea 作废。

### 1 数据集

**关键判据与 A/B 类 idea 不同**：本任务需要的不是错误标注质量，而是**同一任务的参与者数量**——step 内部的自然变异只在人多时才出现。

| 数据集 | 参与者 | 用途 | 依据 |
|-------|-------|------|------|
| HoloAssist | **222**（原文 "We recruited 222 participants"） | hard-normal 主要来源 | 参与者最多，自然变异最丰富 |
| Assembly101 | **53**（原文 "We recruited 53 adults (28 males, 25 fe-"） | hard-normal 次要来源 + 跨域 | 原文明确宣称 "Rich sequence variation: Participants vary in skill" |
| EgoPER | **11** | **被否定的对象**，不作 hard-normal 来源 | 正常视频仅在 step 顺序上变化；modification 被标为错误 |
| CaptainCook4D | 8 | 仅作真错误来源之一 | 参与者过少；且 286 个 Missing Step 时间戳为 -1.0 |

> EgoPER 的双重角色要写清：它提供真错误样本与最接近的 baseline 设定，同时它的协议是本文要否定的东西。不能同时用它当 hard-normal 来源——那会自证。

### 2 Hard-Normal 构造协议（本文最易受攻击处，必须最严谨）

**设计原则：构造过程必须独立于方法的属性词表，否则是循环论证。**

**步骤 1 — 盲筛（不看属性词表）**：由**不知道方法细节**的标注者，从各数据集的正确执行中筛出「与该 step 的典型做法明显不同，但仍然正确完成了该 step」的片段。筛选提示语中**不出现**本文的任何属性类型名称。

**步骤 2 — 独立正确性确认**：每个候选片段由 ≥3 名标注者独立判定「这是否是该 step 的一次成功执行」。仅保留多数判定为正确的片段。

**步骤 3 — IAA 报告**：报告标注者间一致性（Fleiss' κ 或 Krippendorff's α）。这是**必须项**：综述已记录标注者对「可容许 vs 错误」本身存在分歧，若不报 IAA，整个指标可被质疑为主观构造。低一致性的片段单独成一档报告，不混入主集。

**步骤 4 — 事后分类（仅用于分析，不参与筛选）**：筛完之后，才按属性类型给 hard normals 打标（未见工具 / 换手 / 合法顺序变动 / 未见环境等），用于分维度分析。**顺序不能颠倒**。

**步骤 5 — 泄漏检查**：确认 hard normals 与训练用的正确示范不来自同一参与者、同一 session。

> 若资源允许，最强的做法是让第三方（非作者）执行步骤 1–3，并在论文中说明。这是回应循环论证指控的最直接方式。

### 3 必备实验清单

#### 3.1 主实验：hard-normal 上的选择性检测

**目的**：验证 RQ1。

**核心结果曲线**：$\text{Error Recall}$ vs $\text{Hard-Normal FAR}$，本文方法与全部 baseline 画在同一张图上。

**汇报要求**：在 matched error recall 下比较 FAR；在 matched FAR 下比较 recall。两个方向都要给，防止单向挑选。

#### 3.2 弃权行为分析（防御性实验，必做）

**目的**：回应「弃权吞掉 benchmark」的攻击（这是审稿人最可能的一击）。

- 弃权率 vs 错误召回曲线，**画上 always-abstain 平凡基线**；
- 报告 coverage 下的 selective risk；
- 明确给出：在 coverage = 90% / 80% / 70% 时各项指标分别是多少。

> 若本文方法的优势只在极低 coverage 处出现，应当诚实写出并讨论，不得只报最优点。

#### 3.3 示范数量消融（防御性实验，必做）

**目的**：证明三值划分不是样本量的伪影。

横轴为示范数 $N \in \{3,5,10,20,\dots\}$，纵轴为 `required`/`free`/`unknown` 三者比例。**期望 `unknown` 单调收缩、`free` 单调增长**，且在可用区间内 `unknown` 不占绝对多数。

> 这条曲线若不好看（例如 N=20 时仍 80% unknown），说明方法在实际可得的数据量下不可用，需要回到 §3.3 的降级方案。**建议在方法实现前就用小样本先跑一次估计。**

#### 3.4 不变量质量直接评测（对应主要风险）

**目的**：回应「不变量真的学对了，还是过拟合 few-shot？」——不能只报下游 F1。

- 在若干 step 上人工书写参考规范（golden spec），报告 required precision/recall、free 识别率；
- `unknown` 校准：对 `unknown` 中的属性，用额外数据事后判定其真实归属，报告校准曲线；
- 定性展示：至少一组「学对了」与一组「学错了」的规范全文。

#### 3.5 消融

| 变体 | 替换为 | 检验什么 |
|-----|-------|---------|
| w/o unknown | 强制二值（required/free） | **三值化的必要性，最重要的一条** |
| w/o 类型层级抽象 | 只用最具体取值 | 抽象是否防止了 few-shot 过拟合 |
| w/o MDL | 无描述长度惩罚 | 琐碎规则是否被抑制 |
| w/o Nec（因果耦合） | 恒定即 required | 必要性证据是否有效区分采集偏置 |
| oracle attributes | 人工提供属性 | 解耦感知误差与归纳能力 |

#### 3.6 泛化实验（对应 RQ3）

未见工具 / 未见执行者 / 未见合法顺序 / 未见环境 / seen step + unseen 属性组合，五档分别报告。

#### 3.7 领域常规附加实验

在标准 EgoPER / Assembly101-O 协议上报告常规指标（EDA/AUC/F1），**即使不是 SOTA 也要给**。目的是证明本文方法没有为了低误报牺牲基本检测能力。若确有下降，诚实报告并讨论权衡。

### 4 资源预估

| 实验 | 预估显存 | 预估时长 | 组数 |
|------|---------|---------|------|
| 实验 #0（baseline 复现） | ~24GB | 数小时/数据集 | 2 |
| 属性抽取前端（7B VLM，冻结） | ~20GB（bf16）或 4-bit 更低 | 特征/属性缓存一次，数小时 | — |
| 归纳算子（符号 + 小模型） | <8GB | 分钟~小时级 | 多组 |
| 主实验 + 消融 | ~24GB | 小时级/变体 | ~10 |

> 1 张 4090 可完成主实验，2 张适合并行跑数据集与消融。全程无需微调大 VLM——与 EgoPER/AMNAR/GTG2Vid 的算力量级一致（这几篇都是冻结特征 + 小头，单卡数小时/任务）。

---

## 开工前必须先验证的三件事（在方法实现之前）

1. **实验 #0**：AMNAR/EgoPER 在 hard normals 上是否真的误报。不成立则止损。
2. **属性抽取精度**：手标 100~200 个 step，量 7B VLM 的属性抽取准确率。**低于 80% 就要改设计**（收窄词表或走降级方案）。
3. **三值比例的可用区间**：小样本先估 `unknown` 随 N 的收缩速率，确认存在可用工作区间。

> 前 3 周只做这三件事，不写方法主体，不写论文。#0 失败的话，已写的部分全部作废。

---

## 主要风险与应对

| 风险 | 严重度 | 应对 |
|------|-------|------|
| 弃权吞掉 benchmark，低误报靠 coverage 换来 | **高** | §3.2 弃权曲线 + always-abstain 基线；所有指标与 coverage 成对汇报 |
| 自造 hard-normal + 自选属性词表 = 循环论证 | **高** | §2 盲筛协议（筛选早于打标）+ IAA + 第三方执行 |
| 感知前端精度不足（前例仅 48.4%） | **高** | §3.3 降级方案 + oracle-attribute 对照组 |
| 认识论洞察归属（Chou & Berenson 已拥有） | 中 | 显式让渡；只声称 video/属性层实例化 |
| AXG-Reasoner 输出端重叠 | 中 | related work 正面处理：结构 vs 规范、事后解释 vs 挖掘约束、无三值无弃权 |
| 「不是 SOTA」 | 中 | §3.7 常规指标照报 + 明确本文换的是评测轴而非刷点 |
| 标注者对「可容许 vs 错误」本身分歧 | 中 | IAA 必报；低一致性样本单列 |

---

## 待核实清单

- [ ] Chou & Berenson 2018 的确切 venue、年份、标题（位置：Part 1 §3，原因：来自二手检索，未读原文）
- [ ] Bayesian Specification Inference / PUnS 的确切出处与年份（位置：Part 2 §2.2，原因：同上）
- [ ] AXG-Reasoner 是否确实无任何弃权/三值机制（位置：Part 2 §2.3，原因：基于摘要与 HTML 正文，未读全文 PDF）
- [ ] HoloAssist / Assembly101 中可用 hard-normal 的实际数量（位置：Part 3 §1，原因：需实际筛选后才知道，是可行性的关键未知数）
- [ ] 7B VLM 属性抽取精度（位置：Part 2 §3.3，原因：需实测）
- [ ] 「无工作以合法非典型执行评测错误检测器」这一空白（位置：Part 2 §2.3，原因：Semantic Scholar 本轮 429 无覆盖，arXiv 限流有确认过的假阴性；置信度中高而非高）

---

> ⚠️ **本报告为 idea 阶段产物**。方法细节（尤其 $\text{Nec}$ 的具体实现与感知前端的选型）在实验 #0 与属性抽取精度实测之后需要修订。
