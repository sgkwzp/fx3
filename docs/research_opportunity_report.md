# Procedural Video Error Detection：新研究任务机会报告

**检索截止日期：** 2026-07-26  
**执行模式：** 文献趋势扫描 + novelty check + 严格 idea 评审  
**检索范围：** 本目录 50 余篇论文及文本抽取，并对 arXiv/DBLP 做公开安全的精确关键词复查  
**总体信号：** **RESEARCH**。目前没有发现直接定义下述完整任务的论文，但 2026 年相邻工作非常接近，论文必须把“预后目标”和“无干预反事实”做实，不能只换术语。

## 1. 核心结论

最值得投入的新任务是：

> **Procedural Error Prognosis（PEP，程序性错误预后）：给定流式程序视频前缀和目标流程，预测当前偏差在不干预时是否会导致下游目标失败、哪些未来里程碑会受影响，以及恢复代价超过给定预算前的最后干预决策点。**

可直接使用的论文标题是：

> **Beyond Detection: Forecasting Error Propagation and Intervention Deadlines in Procedural Videos**

这比继续做二分类 detector 更有成立空间，因为以下任务已经被占领：

- 离线/在线错误检测；
- 带自适应退出的早期错误判断；
- 错误类型识别与语义、时间、空间归因；
- action effect 与 object state 建模；
- 基于 VLM 的错误解释；
- 主动的 interrupt/silent 决策和恢复建议生成；
- 长视频通用主动选帧与证据检索。

尚未被充分建模的是 **prognosis（预后）**：不仅判断“现在是否错了”，还要判断“这个偏差会不会向后传播、是否值得打断、最晚什么时候必须干预、届时修复代价多大”。2025 年综述明确将 error dependency/propagation 列为开放方向；已有 accumulated-error 工作则主要是规则驱动、局限于装配场景。

## 2. 已有任务版图

| 已被占领的任务簇 | 本地代表工作 | 预测目标 | 为什么没有占领 PEP |
|:---|:---|:---|:---|
| 离线错误检测 | EgoPED、AMNAR、AEM、ZeProM | 当前片段正常/错误 | 不预测未来后果或干预期限 |
| 在线错误检测 | PREGO、DTGL、MistSense、ESTANet | 当前流式步骤是否错误 | 优化检测时机，不建模下游风险 |
| 早期错误检测 | MistExit | 最早何时能可靠输出正常/错误 | exit time 是观测效率决策，不是不可恢复期限 |
| 细粒度归因 | MATT | 违反的语义角色、事后 PNR、空间区域 | PNR 在看完 attempt 后定位，不从早期前缀预测未来风险 |
| 错误识别/解释 | GTG2Vid、AXG-Reasoner、coherent PMD | 错误类型或文本理由 | 解释当前错误，不预测传播链与恢复预算 |
| 效果与状态 | AEM、MOSCATO、state-change counterfactual | 已发生的动作效果或物体状态 | 可作为表征基础，但没有定义错误预后任务 |
| 主动辅助 | PWR、Streaming Interventions、GuideMe、Vinci2 | interrupt/silent 与纠正建议 | 标注“教练何时说话”，不建模无干预后果、紧迫度或修复成本 |
| 预测式反馈 | TRAFA | 近期手部运动与即将发生的错误放置 | 单一受控装配、短期动作预防，没有长时因果传播 |
| 主动感知 | AVP、ACT2SEE | 为查询选择帧/证据 | 通用 prior art 很强，仅迁移到 PMD 不足以构成主创新 |
| 错误累积 | Every Mistake Counts、IndustReal | 基于规则的 accumulated mistake | 能标识下游错误，但不从像素预测传播链、反事实修复成本和期限 |

## 3. 候选任务严格排序

分数是 1-5 的 idea 阶段诊断信号，不是录用概率。

| 排名 | 候选任务 | 加权分 | 当前成熟度 | 发展潜力 | 主要问题 |
|---:|:---|---:|:---:|:---:|:---|
| 1 | **Procedural Error Prognosis：传播 + 干预期限** | **4.00** | 低 | 高 | deadline/recoverability 必须有可操作定义，不能靠主观打分 |
| 2 | Goal-Equivalent Deviation Assessment | 3.46 | 低 | 中 | AMNAR 已处理多个合法后继；PIE-V 已显式区分 benign variant 与 consequential error |
| 3 | Active Evidence Acquisition for Mistake Diagnosis | 3.26 | 低 | 中 | AVP、ACT2SEE、coherent PMD 和 AXG 选帧使其容易被视为通用主动感知的应用 |

第一名还不能直接投稿，但最值得做 pilot。它的核心阻塞点是标签定义，能被小规模实验快速证伪；后两项在扣除最近邻工作后，创新余量明显更薄。

## 4. 推荐任务定义

### 4.1 中心问题

给定视频前缀 V<=t、目标流程 P 和当前执行状态，模型需要回答：

1. 如果不干预，当前偏差是否会在未来违反任务约束或终局目标；
2. 哪些下游 milestone/object state 会受影响；
3. 在修复成本超过预算 B 或错误变得不可逆之前，最后可干预的决策点是什么。

论文的中心输出应收敛为 **need-by-when**。“传播链”和“修复成本”用于提供结构化证据与辅助监督，不应写成三个松散拼接的新任务。

### 4.2 输入与输出

**输入**

- 流式第一人称或多视角视频前缀；
- 任务目标或流程文本；
- 第一版可使用给定 action boundary，完整版再使用预测 boundary。

**主要输出**

- p_need(t)：不干预时，在预测范围 H 内导致目标/约束失败的概率；
- d(t)：距干预期限的剩余决策步数，或离散 survival/hazard 分布；
- C(t)：受影响的未来里程碑或物体状态谓词集合。

**辅助输出**

- k_repair(t)：最小 undo/redo/replacement 成本，以决策步数或归一化持续时间计。

### 4.3 可操作定义

- **Benign deviation：** 偏离 canonical trace，但不经额外修复仍满足目标与安全约束。
- **Self-recoverable deviation：** 执行者在后续自然操作中自行恢复正确状态。
- **Recoverable error：** 存在成本不超过预算 B 的有效修复路径。
- **Critical error：** 在无干预反事实中，未来 prerequisite 或终局目标会失败。
- **Intervention deadline：** 仍存在预算内有效修复的最后决策点。

deadline 优先用离散决策点定义，而不是原始秒数，因为不同人的执行速度差异很大。

## 5. 最近邻工作与剩余创新

| 最近邻工作 | 已经覆盖什么 | PEP 剩余的新内容 | 风险 |
|:---|:---|:---|:---:|
| Every Mistake Counts / Spatial and Temporal Beliefs | 用 transitive/intransitive 规则处理累积的顺序错误 | 从视频和流程学习未来传播与修复成本，并跨域验证 | 高 |
| IndustReal | 长时程序/执行错误与灵活执行顺序 | 没有显式因果链、无干预反事实或 deadline 标签 | 中 |
| Vision-Based Mistake Analysis 综述 | 明确提出学习 error transition likelihood 和 propagation | 只是开放方向，没有形成任务、协议或模型 | 中 |
| MistExit | 基于前缀的早期错误分类 | 预测证据何时充分，不预测何时来不及修复 | 中 |
| MATT | 语义归因与事后 Point-of-No-Return | 从更早前缀预测未来 PNR/deadline 和下游后果 | 高 |
| AEM | 建模动作完成后已观察到的结果 | 尚未建模反事实下游效果和恢复成本 | 中 |
| PIE-V | 生成 consequential、coherent、recoverable 的错误-纠正轨迹，并手工设定严重性/检测/恢复先验 | 学习视频落地的预后模型，并在真实轨迹上验证 | 高 |
| PWR / GuideMe / Vinci2 | 判断是否/何时打断并生成恢复建议 | 不输出校准后的无干预风险、传播集合或预算条件下的 deadline | 高 |
| Streaming Interventions | 流式及时纠错 | detect-and-correct timing 不等于下游失败预后 | 中 |
| TRAFA | 在动作完成前做短期运动预测 | 缺少通用长时流程状态、传播结构与恢复预算 | 中 |

**真正的 novelty delta：** 将因变量从 mistake now? 或 interrupt now? 改为“如果不干预会不会造成下游失败，以及预算内恢复窗口还有多长？”。只有当论文显式包含 **no-intervention counterfactual** 和 **budget-conditioned deadline** 时，这个差异才经得住最近邻扣除。

## 6. 方法假设

暂定方法名：**Causal Twin Rollout Network（CTRNet）**。

### 6.1 Procedure-State Induction

先将冻结视频编码器的缓存特征转换为紧凑的 action/object-state token 流。根据流程文本和正常视频诱导或检索 procedure graph；节点表示 milestone，边表示 prerequisite 与 expected effect。这样不需要为每种错误收集大量训练视频。

### 6.2 Counterfactual Twin Rollout

从当前推断状态展开两个未来：

- **continue branch：** 不修复并继续执行时的未来状态；
- **repair branch：** 执行最低成本合法纠正后的未来状态。

两条分支的差异用于估计受影响 milestone 和反事实风险。这是方法的中心机制。如果最后只是“通用 VLM + 四个分类头”，论文会退化成增量工作。

### 6.3 Deadline Hazard Model

在未来离散决策点上预测 hazard：恢复成本首次超过 B 的概率。该形式可以处理删失样本，例如错误在不可逆之前被纠正，或视频结束时仍可恢复。

### 6.4 Calibration and Abstention

校准 p_need，并允许模型在视觉证据不足时 abstain。实际价值不是“每个偏差都报警”，而是在有限干预预算下优先处理高后果错误。

## 7. 数据方案：方法论文，不做纯 benchmark

### 7.1 Pilot 场景

先使用 Assembly101 与 Every Mistake Counts 扩展标注。装配任务的部件连接、依赖和累积顺序错误易于审计，适合验证因果定义。再用 IndustReal 测试未见执行错误和灵活步骤顺序。

### 7.2 跨域验证

使用 CaptainCook4D 验证烹饪域；在确认公开发布与许可后，可用 EgoProactive 的 deviation-recovery 轨迹。PIE-V 可用于受控增强，但论文主结果必须包含自然录制错误。

### 7.3 标注单元

每条选中轨迹标注：

- root deviation 和第一个受影响 milestone；
- 下游受影响 milestone；
- 观察到的自纠正/恢复步骤；
- 每个决策点的最小合法修复；
- 固定预算下的修复成本和 deadline；
- 最终目标/约束是否满足。

确定性流程优先从规则和几何约束生成标签；含歧义的烹饪样本需双人标注。LLM 只能提出候选，不能作为最终 ground truth。

### 7.4 最小可行规模

第一轮只做 3-5 个装配流程、200-300 条轨迹。只有当标注一致性和基线难度通过 stop/go test 后再扩展。完整论文大概率需要约 1,000 条以上经核验的 error/recovery 轨迹和至少两个领域，但因果可审计性比单纯 clip 数量重要。

## 8. 能检验中心主张的实验

### 8.1 主指标

- intervention-need AUPRC 与 calibration error；
- deadline 的 decision-step MAE 与 time-dependent C-index；
- cascade milestone node/edge F1；
- recovery-cost 排序相关系数；
- **budgeted intervention utility：** 避免的终局失败，扣除错误打断与修复成本。

### 8.2 必须比较的基线

- PREGO/DTGL 风格在线错误分数；
- AMNAR/AEM/ZeProM 的流式前缀适配；
- 将 MistExit early confidence 作为 urgency proxy；
- 将 MATT PNR 预测适配到视频前缀；
- 协议允许时使用 PWR/GuideMe interrupt score；
- Every Mistake Counts 规则引擎；
- 冻结 VLM 直接 prompting；
- 无因果图的 temporal Transformer；
- 去掉 repair branch 的 CTRNet。

### 8.3 决定性消融

- action-only、object-state-only、两者联合；
- learned dependency graph 与 oracle graph；
- factual-only 与 twin counterfactual rollout；
- 无 deadline loss 与 hazard loss；
- synthetic augmentation 与 real-only；
- 域内与 unseen task/error type；
- ground-truth 与 predicted action boundary。

## 9. 1-2 张 RTX 4090 的可行性

可行配置：

- 冻结公开 video encoder，单次缓存 clip feature；
- 在缓存特征上训练 50-200M temporal/graph model；
- 如需生成状态/动作文本，对 7B VLM 做 4-bit LoRA；
- 不做端到端视频大模型预训练，不用 32B+ 模型，不做全分辨率密集视频训练。

| 阶段 | 硬件 | 粗略成本 |
|:---|:---:|:---|
| 特征抽取 | 1x4090 | 数小时到数天，取决于数据规模 |
| Pilot CTRNet | 1x4090 | 单次训练数小时到约 2 天 |
| 完整消融 | 2x4090 | 合计约 20-40 GPU-days |
| 可选 7B LoRA | 1-2x4090 | 4-bit、短 clip、gradient checkpointing 下可行 |

这个方向的主要瓶颈是标注和协议设计，不是算力。

## 10. 严格 reviewer panel

**领域 reviewer：** 最强支持点是把 PMD 从诊断推进到可行动的预后，直接回应已有综述指出的开放问题。拒稿点是：若标签只是重新命名 accumulated mistake，则任务增量明显。

**方法 reviewer：** 最强支持点是 counterfactual twin rollout 将视觉状态、因果依赖和恢复成本统一起来。拒稿点是：若只是通用 VLM 加多个预测头，没有技术 insight。

**实验 reviewer：** 最强支持点是 budgeted intervention utility 直接检验“为什么预后有用”。拒稿点是：只有合成数据或让 LLM 评判 deadline，会导致证据闭环自证。

**AC/venue reviewer：** 新视频任务 + 方法 + 跨域自然错误证据适合 CVPR/ICCV；若因果建模强于数据贡献，也可考虑 AAAI/NeurIPS。只有一个小型装配 benchmark 时更像 workshop。

**prior-art reviewer：** 最强反对意见是 PEP 只是 MistExit、MATT PNR、PWR recovery 与 Every Mistake Counts 的显然组合。必须回答：这些工作均不估计“无干预下游结果”和“预算条件下最后可恢复决策点”，并通过统一协议和消融证明该差异有实际价值。

## 11. Winner scorecard

| 维度 | 权重 | 分数 | 置信度 | 扣分依据 | 提分条件 |
|:---|---:|---:|---:|:---|:---|
| 问题重要性 | 12 | 5 | 4 | 及时干预和阻断传播具有直接部署价值 | 保留 outcome-level 评测 |
| 相对已有工作的创新性 | 14 | 4 | 4 | 未发现直接同题，但 PIE-V/MATT/PWR 很接近 | 投稿前持续检索 2026-2027 工作 |
| 概念创新 | 12 | 4 | 4 | 从 diagnosis 到 prognosis 的转变成立 | 以 need-by-when 统一任务 |
| 方法可靠性 | 14 | 4 | 3 | twin rollout 合理，但依赖状态诱导质量 | 证明 state graph 可校正且准确 |
| 简洁性 | 8 | 4 | 3 | 一个因果机制支撑所有输出 | 避免增加互不相关模块 |
| 资源可行性 | 8 | 4 | 4 | 缓存特征和轻量图模型适合 4090 | 核验数据许可与特征吞吐 |
| 实验证据可说服性 | 10 | 3 | 3 | 现有数据没有原生 counterfactual deadline | 获得真实、可审计标签和预算效用结果 |
| Venue fit | 8 | 4 | 4 | 与 CV/AI 主线高度相关 | 跨域视频验证，不能只做装配 |
| 时机 | 6 | 5 | 4 | 2026 工作正快速转向 proactive assistance | 尽快完成，防止被占领 |
| 风险调整后的发表潜力 | 8 | 3 | 3 | 标注循环性尚未解决 | pilot 全部通过并击败强 intervention baseline |

**加权分：** 4.00 / 5.00  
**建议：** revise；pilot 通过后 accept-to-develop  
**当前投稿成熟度：** 低  
**发展潜力：** 高  
**置信度：** 文献边界中高；标签可行性中等

## 12. 致命风险与 stop/go test

| 风险 | 严重度 | 检查方式 | 决策规则 |
|:---|:---:|:---|:---|
| deadline 标签主观 | 致命 | 双人标注 200 条 pilot 轨迹 | 一致性低于 0.60 时重定义；高于 0.70 才放心扩展 |
| 只靠 action label 就能完成 | 高 | 比较 video、action-only、procedure-only | 必须有清晰的视频 grounding 增益和困难视觉样本 |
| 合成伪影主导 | 致命 | PIE-V 训练、纯自然错误测试 | 增益消失则不能把合成数据作为主线 |
| counterfactual branch 无价值 | 高 | 去掉 repair branch 和 graph | calibration、deadline、utility 三项都应有稳定增益 |
| 不优于“检测到就全部打断” | 致命 | 固定预算 intervention simulation | 相同或更高阻断率下必须减少打断次数 |
| 跨域崩溃 | 高 | assembly-to-cooking / unseen error transfer | 无迁移时缩小 claim 或重做状态表征 |

## 13. 候选 Research Questions

以下仍是待用户确认的候选，不是已锁定的 ResearchPilot RQ。

**RQ1（核心）：** 程序视频模型能否预测已观察偏差是否会传播为下游任务失败，而不只检测偏差已经发生？

**RQ2（机制）：** 对“继续不修复”和“最小修复”两条状态轨迹做反事实比较，是否能比 error score 或单分支 rollout 更准确地预测传播链和干预期限？

**RQ3（边界）：** 错误预后在 unseen procedure、unseen error type、不准确 action boundary 和 goal-equivalent 灵活执行顺序下是否稳定？

## 14. 最近邻本地文献

- [Vision-Based Mistake Analysis in Procedural Activities: A Review of Advances and Challenges](../2510.19292v2.pdf)
- [Every Mistake Counts in Assembly](../Every%20Mistake%20Counts%20in%20Assembly.pdf)
- [Spatial and Temporal Beliefs for Mistake Detection in Assembly Tasks](../004_Spatial%20and%20temporal%20beliefs%20for%20mistake%20detection%20in%20assembly%20tasks.pdf)
- [IndustReal](../009_Schoonbeek_IndustReal_A_Dataset_for_Procedure_Step_Recognition_Handling_Execution_Errors_WACV_2024_paper.pdf)
- [AMNAR](../023_Huang_Modeling_Multiple_Normal_Action_Representations_for_Error_Detection_in_Procedural_CVPR_2025_paper.pdf)
- [MistExit](../015_MistExit%20Learning%20to%20Exit%20for%20Early%20Mistake%20Detection%20in%20Procedural%20Videos.pdf)
- [Mistake Attribution](../014_Mistake%20Attribution%20Fine-Grained%20Mistake%20Understanding%20in%20Egocentric%20Videos.pdf)
- [Action Effect Modeling](../019_Procedural%20Mistake%20Detection%20via%20Action%20Effect%20Modeling.pdf)
- [How to Correctly Make Mistakes / PIE-V](../016_Loginova_How_to_Correctly_Make_Mistakes_A_Framework_for_Constructing_and_CVPRW_2026_paper.pdf)
- [Plan, Watch, Recover](../2606.04970v1.pdf)
- [Streaming Interventions](../2606.09547v2.pdf)
- [GuideMe](../2607.02991v1.pdf)
- [Vinci2](../2607.11523v1.pdf)
- [AXG-Reasoner](../017_Lee_AXG-Reasoner_Error_Detection_and_Explanation_in_Long_Task_Videos_with_CVPR_2026_paper.pdf)
- [Active Video Perception](../2512.05774v2.pdf)
- [ACT2SEE](../Q._Act2See_Emergent_Active_Visual_Perception_for_Video_Reasoning_CVPR_2026_paper.pdf)

## 15. 检索边界

- 对 procedural error propagation、mistake consequence、recoverability、intervention deadline、goal-preserving deviation、root cause、active evidence 做了精确 arXiv 查询，没有发现 procedural video 中直接同题的任务。
- “精确关键词未命中”不是 novelty proof；不同论文可能使用不同术语，且 2026 年该方向变化很快。
- 最强重叠是概念相邻而非任务相同：综述提出传播建模；PIE-V 构造错误-恢复轨迹；PWR/GuideMe/Vinci2 做干预；MATT 做 PNR；Every Mistake Counts 做累积顺序错误。
- 投稿前必须用最终公开安全的任务表述，重新检索 arXiv、OpenReview、CVPR/ICCV/NeurIPS/AAAI 录用列表以及 Google Scholar/Semantic Scholar。

