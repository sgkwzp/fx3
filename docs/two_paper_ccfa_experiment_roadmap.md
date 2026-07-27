# 两篇 CCF-A 论文的实验路线图

**研究领域：** Procedural Video Error Detection  
**目标：** 两篇相互关联、但核心贡献可独立成立的方法论文  
**算力约束：** 1–2 张 RTX 4090  
**文档日期：** 2026-07-26

---

## 0. 最终建议

推荐完成以下两篇论文：

1. **Paper 1：Procedural Error Prognosis**
   - 不再把“错误后由谁恢复”作为中心任务。
   - 核心改为：给定已经发生的源错误和当前视频前缀，预测错误是否继续存在、会影响哪些未来步骤、后果何时首次显现。
   - 它回答的是“这个错误是否值得现在优先处理”，不是猜测某个人主观上愿不愿意纠正。

2. **Paper 2：Typed Procedural Invariant Induction**
   - 从正常程序视频中归纳带类型、带证据等级的规则。
   - 区分 `required`、`witnessed-free` 和 `unknown`，再据此做 `Alarm / Pass / Abstain`。
   - 它回答的是“一个非典型动作到底是真错误、合法变化，还是证据不足”。

两篇论文的逻辑关系是：

```text
Paper 2：先判断偏差是否真的违反必要规则
                     |
                     v
Paper 1：若已确认是错误，再预测它会不会向后传播、何时产生后果
```

二者可以复用视频特征、步骤解析、状态表征和任务图，但不要写成一篇包含所有目标的大论文。每篇都必须有一个清晰中心问题和一条独立证据链。

---

## 1. 两篇论文共同遵守的原则

### 1.1 不做无法由数据支持的因果声称

- 观察到某人之后自我纠正，不等于错误本身“必然可自愈”。
- 观察到错误没有传播，不等于干预无效或错误无害。
- 正常示范中某属性从未变化，不等于该属性是必要条件。
- 任务图、LLM 或方法自身生成的标签，不能再作为证明该方法正确的独立真值。

### 1.2 主结果必须来自自然视频

PIE-V 等合成数据可以用于预训练、数据增强和可控实验，但不能单独支撑主要结论。主测试集必须包含自然录制的真实错误和真实合法变化。

### 1.3 严格流式协议

在预测时刻 \(t\)，模型只能访问 \(V_{\le t}\)。未来动作、未来字幕、完整视频摘要、事后错误解释和未来 task graph 节点状态都不得进入输入。

同时报告：

- **Oracle-source setting：** 给定真实源错误边界，单独检验预后或规则推理能力。
- **End-to-end setting：** 使用预测的步骤和错误边界，检验完整系统。

前者用于研究问题，后者用于说明可部署性。不能只报告较容易的 oracle 结果。

### 1.4 防止数据泄漏

划分至少应按以下层级进行：

- 参与者不重叠；
- 视频不重叠；
- 同一错误事件的不同视角不得跨 split；
- 同一任务实例的近重复轨迹不得跨 split；
- 额外报告 unseen toy、unseen task 或 unseen procedure split。

### 1.5 结果不应只靠更多参数

在同一冻结视频编码器和相近可训练参数量下比较方法。核心增益必须来自结构化机制，而不是换用更大的闭源 VLM。

---

# Paper 1：Procedural Error Prognosis

## 2. 论文定位

### 2.1 推荐题目

> **Will This Error Propagate? Source-Conditioned Prognosis in Streaming Procedural Videos**

中文可表述为：

> **这个错误会传播吗？流式程序视频中的源错误条件预后**

### 2.2 为什么不再研究“由谁恢复”

“由谁恢复”存在明显混杂：

- 是否自我纠正受个人熟练度、注意力、性格和任务策略影响；
- instructor 是否介入受教学策略影响；
- HoloAssist 中 instructor 的语言本身可能直接泄漏标签；
- 不同数据集对 self/external/unresolved 的定义不对称；
- 对很多辅助系统而言，“谁最终纠正”不如“错误是否即将造成后果”有用。

因此，第一篇论文不应把 recovery actor classification 作为主贡献。即使保留，也只能作为附录分析。

更有用、也更可预测的中心问题是：

> 已知时刻 \(\tau\) 发生了源错误，仅使用 \(\tau\) 之前和附近的视频证据、当前程序状态及任务结构，预测该错误是否会影响未来步骤、首先在哪里显现，以及执行何时重新进入有效状态。

### 2.3 严格主张边界

论文可以声称：

- 预测**观测执行策略下**的错误持续与后续影响；
- 从视频状态和程序依赖中定位未来高风险步骤；
- 比当前错误分数、任务图后继规则和通用时序模型更早、更准地预测后果；
- 在有限人工检查或干预预算下，更好地排序需要优先关注的错误。

论文不能直接声称：

- 预测一个人“主观上是否愿意改”；
- 仅凭观察数据识别真正的 `do(no intervention)` 因果效应；
- 找到客观唯一的“最后可恢复点”；
- 从 Assembly101 的 correction 标签自动获得普适的源错误—后果因果链。

---

## 3. 任务定义

给定：

- 流式视频前缀 \(V_{\le \tau}\)；
- 当前源错误 \(e_\tau\)；
- 当前步骤 \(s_\tau\)；
- 目标流程或程序图 \(G\)；

模型输出：

1. **Persistence**
   - 在未来第 \(h\) 个决策步骤时，源错误影响仍存在的概率；
   - 预测 \(p_{\text{persist}}(h \mid V_{\le\tau}, e_\tau, G)\)。

2. **Affected Future Steps**
   - 每个未来 milestone 是否受到源错误影响；
   - 输出多标签集合 \(\hat A_e\)。

3. **First Manifestation**
   - 错误后果首次可观测地影响哪个未来步骤；
   - 输出离散步骤分布或 hazard。

4. **Return to Valid State**
   - 执行何时重新进入满足当前程序约束的状态；
   - 对视频结束仍未恢复的样本使用 right-censoring。

其中第 2 和第 3 项应为主任务，第 1 和第 4 项是辅助任务。这样论文的价值落在“后果预警”，而不是个体行为猜测。

---

## 4. 数据与标注方案

### 4.1 数据集分工

| 数据集 | 用途 | 可以提供什么 | 不能假设什么 |
|:---|:---|:---|:---|
| Assembly101 | 主自然视频域 | correct/mistake/correction 段、长程装配、官方 split | 没有通用的源错误→受影响步骤链接 |
| Every Mistake Counts | 主标注起点和规则基线 | 153 个 generic ordering mistakes、46 个 accumulated mistakes | 46 个 accumulated 样本不足以单独训练大模型 |
| IndustReal | 外部小规模验证 | 持续错误状态、组件状态向量、灵活顺序 | 仅约 38 个错误完成事件，不足以做主训练集 |
| CaptainCook4D | 跨域自然测试候选 | 丰富烹饪错误及步骤级时间段 | 发布 JSON 没有传播字段；Missing Step 的错误时刻可能无定义 |
| PIE-V | 合成预训练与可控压力测试 | root error、cascade-consistent edit、correction trace | 合成结果不能替代自然视频主测试 |

### 4.2 必须新增的标注

对每个可审计的自然错误 episode，标注：

- `source_error_id`：源错误；
- `source_step`：错误发生在哪个步骤；
- `affected_step_ids`：哪些后续步骤被该源错误实际影响；
- `manifestation_step`：第一个出现可观测后果的步骤；
- `valid_state_return_step`：重新进入有效程序状态的步骤；
- `censored`：视频结束时是否仍未回到有效状态；
- `evidence_span`：支持“受影响”的视觉或状态证据；
- `confidence`：标注者置信度；
- `ambiguous`：是否存在多种合理解释。

“受影响”的定义必须要求：

> 后续步骤的输入状态、执行方式或结果因源错误而不同，并且标注者能指出可观察证据或明确的程序依赖。

仅仅发生在错误之后，不算被影响。仅仅位于 task graph 后继节点中，也不算被影响。

### 4.3 标注流程

1. 专家先在 30–50 条视频上制定 annotation manual。
2. 任务图只用于列出候选未来步骤，不能自动决定标签。
3. 两名标注者独立标注源错误、受影响集合和首次显现点。
4. 第三名标注者仲裁冲突。
5. 报告：
   - affected-step 的 Krippendorff's alpha 或多标签一致性；
   - manifestation step 的 weighted kappa；
   - return-to-valid step 的容差一致率；
   - ambiguous 样本比例。
6. 低一致性错误类型单独列出或排除，不能强行合并。

### 4.4 Pilot 的 stop/go 门槛

先标注 200–300 个自然错误 episode，不要一开始扩到全数据集。

继续扩展至少应满足：

- 源错误到受影响步骤的双人一致性达到可接受水平，建议 alpha \(\ge 0.67\)；
- 至少有数百个“有下游影响”和“无下游影响”的独立 episode，而不是仅有几十个 accumulated mistakes；
- 图后继规则不是近乎完美；
- manifestation step 对多数样本可明确定位；
- 至少 20%–30% 的样本需要视频状态才能区分，而非只看步骤标签。

若这些条件失败，应停止“传播预测”主线，改成规模更小的状态持续预测或数据分析，不宜宣称 CCF-A 完整任务。

---

## 5. 方法应包含的实质机制

建议方法名：

> **Source-Conditioned State Rollout Network（SCSR）**

### 5.1 模块 A：Streaming Video State Encoder

- 使用冻结的预训练视频编码器；
- 离线缓存 2–4 秒 clip feature；
- 学习轻量 temporal adapter；
- 输出动作、物体状态和当前步骤 token。

### 5.2 模块 B：Source Error Delta

估计源错误相对预期步骤效果造成的状态差：

\[
\Delta z_\tau = z_{\text{observed},\tau} - z_{\text{expected},\tau}.
\]

这里的“减法”可以是可学习的 cross-attention discrepancy，而不必是字面向量相减。核心是显式表示“源错误改变了什么”。

### 5.3 模块 C：Procedure-Graph Rollout

- 以 \(\Delta z_\tau\) 为条件沿程序图传播；
- 对每个未来节点计算受影响概率；
- 传播门由当前视觉状态、先决条件和 expected effect 共同决定；
- 允许某些错误影响在中间步骤被吸收，而不是默认所有后继都受影响。

### 5.4 模块 D：Discrete-Time Hazard Heads

分别预测：

- 首次显现 hazard；
- 返回有效状态 hazard；
- 到视频结束仍未恢复的吸收概率。

使用离散 survival loss 处理 right-censoring。不要把删失样本当成“从不恢复”的普通负样本。

### 5.5 为什么该机制可能达到 CCF-A 方法要求

中心技术假设是：

> 错误传播不是普通未来动作预测，而是“源错误造成的状态差”沿程序依赖传播、衰减或被吸收的过程。

如果最后实现只是冻结特征加四个 MLP 头，这篇论文很难成立。必须通过消融证明 source delta、图传播和 hazard 建模各自解决了不同问题。

---

## 6. Paper 1 的逐步实验路线

### 阶段 P1-0：先证明任务可定义

**实验 0A：标注一致性**

- 对 pilot 双人独立标注；
- 按错误类型、任务、传播距离报告一致性；
- 展示典型一致、典型冲突和不可判断案例。

**要证明：** “受影响步骤”和“首次显现”不是研究者主观想象。

**实验 0B：标签分布与难度**

- 统计每个源错误影响的节点数；
- 统计传播距离、显现延迟和删失比例；
- 比较有传播与无传播样本的步骤类别分布；
- 检查是否由单一 toy、错误类或视频长度决定。

**要证明：** 任务不是极端长尾，也不是由一个明显元数据字段即可解决。

### 阶段 P1-1：建立不可省略的弱基线

实现以下不依赖复杂视频推理的基线：

| 基线 | 输入 | 用途 |
|:---|:---|:---|
| Frequency prior | source step/error type | 检查类别先验 |
| Graph descendants | task graph | 检查“所有后继都受影响” |
| Shortest-path/dependency rule | task graph | 检查手工传播规则 |
| Source label + MLP | action/error label | 检查纯语义标签是否足够 |
| Video-only temporal model | prefix feature | 检查无任务结构模型 |
| Future action anticipation | prefix feature | 检查普通未来预测能否替代预后 |
| Every Mistake Counts rule engine | step/order | 直接比较已有 accumulated-error 规则 |
| DTGL-style graph representation | video + learned graph | 强图模型基线 |
| AEM-style state/effect feature | video state | 强 action-effect 基线 |
| Prompted VideoLLM | 采样帧 + 流程文本 | 检查通用大模型能力 |
| Full-video oracle | 完整未来视频 | 给出非因果上界，不参与公平排名 |

**要证明：** 新任务不能被频率、步骤标签、任务图后继或普通错误检测分数轻易解决。

### 阶段 P1-2：主实验一——Affected Future Steps

**输入：** 真实源错误边界和视频前缀。  
**输出：** 未来步骤的多标签受影响概率。

主要指标：

- node-level AUPRC，作为首要指标；
- Macro-F1 与 Micro-F1；
- mAP 或 nDCG；
- Recall@K；
- exact affected-set accuracy；
- 按传播距离分层的 recall。

必须报告：

- overall；
- accumulated 与 non-accumulated；
- seen 与 unseen toy/task；
- 短距离与长距离传播；
- oracle graph 与 learned graph。

**要证明：** 模型能在后果发生前，定位真正受到源错误影响的后续节点，而不仅是枚举 task graph 后继。

### 阶段 P1-3：主实验二——First Manifestation

将首次显现建模为离散时间 hazard。

主要指标：

- manifestation-step MAE；
- 容差 \(\pm1\) step accuracy；
- C-index；
- integrated Brier score；
- negative log-likelihood；
- 预测校准；
- forecast lead time。

**要证明：** 模型不仅知道“可能传播”，还能够在后果出现前给出有校准的时间分布。

### 阶段 P1-4：辅助实验——Persistence 与 Return to Valid State

使用 right-censoring survival protocol：

- 对每个未来 step 预测错误影响是否仍存在；
- 视频结束仍未恢复的 episode 标记为删失；
- 分开报告 spontaneous recovery、explicit correction 和 unresolved；
- 不预测或强调 recovery actor。

主要指标：

- time-dependent AUC；
- C-index；
- integrated Brier score；
- horizon-wise calibration；
- median return-step absolute error。

**要证明：** 错误状态持续时间可被视频和流程状态预测，而不是只能做最终二分类。

**解释限制：** 这是 observed-policy conditional prediction。它不能被写成“错误固有的自我恢复概率”。

### 阶段 P1-5：决定性实验——视频是否真的提供因果落地信息

比较：

1. procedure graph only；
2. source action/error label + graph；
3. video only；
4. video + graph；
5. video + graph + state delta；
6. 完整 SCSR。

再人工建立一组：

- 相同 source error label；
- 相同 source step；
- 不同物体状态或错误执行细节；
- 导致不同后续影响。

**要证明：** 视觉状态决定传播是否发生；论文不是对步骤标签和 task graph 做包装。

若 label+graph 与完整模型持平，应停止当前方法主线。

### 阶段 P1-6：核心机制消融

| 消融 | 检验的问题 | 预期观察 |
|:---|:---|:---|
| 去掉 source-error conditioning | 是否真正针对特定源错误 | affected-node 指标下降 |
| 去掉 state delta | 是否需要表示错误改变了什么 | 视觉相似但后果不同的样本下降 |
| 去掉 procedure graph | 长程依赖是否有用 | 长距离传播下降 |
| graph 换全连接 attention | 增益是否只是更多参数 | 图结构在相近参数量下更好 |
| 去掉 absorption gate | 是否能表示错误影响被后续步骤吸收 | 无传播/短传播误报上升 |
| hazard 改普通回归 | survival 建模是否必要 | 删失数据与校准变差 |
| 单任务训练 | 多任务监督是否互相帮助 | 检查增益来自哪一个辅助头 |
| oracle state/graph | 当前瓶颈在哪里 | 定位视觉解析或结构推理上界 |

### 阶段 P1-7：Synthetic-to-Natural 检验

设置：

1. natural-only；
2. PIE-V-only；
3. PIE-V pretrain + natural fine-tune；
4. 混合训练；
5. synthetic pretrain + 少量自然标签。

测试必须只用未参与合成的自然视频。

**要证明：** 合成 cascade supervision 能提高自然错误的样本效率，而不是让模型识别合成痕迹。

若 PIE-V 的优势在自然测试上消失，应将其降为附录，不要作为论文核心。

### 阶段 P1-8：跨任务和跨域泛化

至少完成：

- seen toy → unseen toy；
- seen procedure → unseen procedure；
- seen error type → unseen error type；
- Assembly101 → IndustReal 的零样本或少样本迁移；
- 条件允许时增加 assembly → cooking。

**要证明：** 方法学到的是状态差和程序依赖，不是记住某个玩具的固定传播模板。

CaptainCook4D 若没有可可靠定位的 source time，只使用具有明确时间段的错误子集，不能把 `-1` 的 Missing Step 强行赋予伪时间戳。

### 阶段 P1-9：实际效用——有限预算风险排序

不要声称做了真实干预因果实验。采用更保守、可验证的离线任务：

> 给定只能人工复核或提醒 \(K\) 个错误 episode 的预算，按模型风险排序后能够覆盖多少真实受影响节点或严重后果？

指标：

- budgeted affected-node coverage；
- severe-consequence Recall@K；
- false alert 数量；
- 每次复核覆盖的真实后果数；
- risk–coverage 曲线。

比较：

- 检测到错误就全部提醒；
- 按当前错误置信度排序；
- 按错误类别先验排序；
- 按 task graph descendants 数排序；
- 按 SCSR prognosis risk 排序。

**要证明：** 预测后果比只知道“当前有错”更有操作价值。这是回应“任务有什么用”的关键实验。

### 阶段 P1-10：End-to-End 鲁棒性

逐步替换 oracle 输入：

1. oracle source boundary + oracle step；
2. predicted boundary + oracle step；
3. predicted boundary + predicted step；
4. 完整流式系统。

**要证明：** 方法在真实上游噪声下仍保留价值，同时明确性能损失来自哪里。

---

## 7. Paper 1 的主要结果表应如何组织

建议正文只保留五张决定性表或图：

1. **表 1：任务统计与 IAA**
   - 证明标签有效。
2. **表 2：Affected-step 主结果**
   - 证明模型比图规则、检测模型和时序模型强。
3. **图 1：Manifestation survival/calibration**
   - 证明能提前且校准地预测何时显现。
4. **表 3：机制消融与 video-vs-graph**
   - 证明贡献来自状态差和结构传播。
5. **图 2：Budgeted risk-ranking utility**
   - 证明任务有实际价值。

其余跨域、合成迁移、end-to-end 和定性结果可以进入后续正文或补充材料。

---

## 8. Paper 1 的致命风险

| 风险 | 如何检查 | 决策 |
|:---|:---|:---|
| 源错误→后果标签一致性低 | 200–300 条 pilot 双标 | 重写定义；仍低则停止 |
| 有传播样本太少 | 标签分布统计 | 无法达到数百独立 episode 时缩小任务 |
| graph-only 已接近上界 | video-vs-graph 实验 | 完整模型无稳定增益则停止 |
| 视频贡献可由 action label 替代 | matched-pair 测试 | 无视觉增益则不够 CV 顶会 |
| manifestation 无法可靠定位 | weighted kappa/容差一致率 | 降为区间预测或删除该头 |
| 合成优势不能迁移自然视频 | PIE-V→natural | 合成路线降级 |
| utility 不优于当前错误分数排序 | 固定预算评估 | “预后有用”的核心主张失败 |
| 恢复预测只是在识别人 | participant-disjoint split | 若跨人崩溃，降为附属分析 |

---

## 9. Paper 1 的算力与时间预算

| 阶段 | 主要工作 | 预计资源 |
|:---|:---|:---|
| Pilot | 协议、双标、弱基线 | 4–6 周，以人工为主 |
| 特征缓存 | 冻结视频编码器 | 1 张 4090，约数小时到数天 |
| 主模型开发 | 50M–200M 时序/图模型 | 1 张 4090 |
| 主实验与消融 | 约 30–60 个有效配置 | 2 张 4090，约 20–40 GPU-days |
| 跨域与合成迁移 | 少量微调或零样本测试 | 约 5–15 GPU-days |
| 复现实验 | 3–5 个随机种子用于主表 | 约 10–20 GPU-days |

优先缓存统一视频特征。不要端到端训练大规模视频 backbone，也不要把 32B+ VLM 作为主要方法。

---

# Paper 2：Typed Procedural Invariant Induction

## 10. 论文定位

### 10.1 推荐题目

> **When Is a Deviation Really an Error? Evidence-Calibrated Typed Invariant Induction for Selective Mistake Detection**

中文可表述为：

> **非典型操作何时才是真错误？面向选择性错误检测的证据校准类型化不变量归纳**

### 10.2 中心问题

现有程序错误检测常把“偏离常见示范”当成“错误”。但以下执行可能罕见却正确：

- 换一只手；
- 使用不同但等价的工具；
- 在不违反依赖时调整步骤顺序；
- 使用不同抓取方式；
- 中间状态不同但最终效果相同。

Paper 2 的中心问题是：

> 给定少量正常示范，哪些属性是真正必须满足的，哪些已被证据证明可以变化，哪些仍然无法判断？

### 10.3 三值规范

对步骤 \(s\) 和类型化属性 \(a\)，预测：

- **required：** 有独立证据表明违反该属性会破坏步骤效果、任务目标或安全约束；
- **witnessed-free：** 已观察到该属性发生变化，但执行仍被独立确认有效；
- **unknown：** 当前证据不足以判定 required 或 free。

对应检测输出：

- 违反高置信 `required` → `Alarm`；
- 仅改变 `witnessed-free` → `Pass`；
- 触及 `unknown` 或视觉证据不足 → `Abstain`。

### 10.4 最关键的认识论限制

仅有 positive demonstrations 时：

> “所有示范中都相同”只能说明 observed invariant，不能证明 semantic necessity。

因此 required 规则必须引入至少一种独立证据：

- 人类专家判断；
- 任务手册或文字步骤的语义约束；
- 物理或安全约束；
- 真实负例；
- 经人工验证的反事实；
- 可验证的动作效果或终局状态。

如果 required 标签完全来自 VLM 常识或“正常视频中从未变化”，论文会形成循环论证。

---

## 11. 类型化属性词表

第一版不要追求开放世界全部属性。选择可标注、可观察、与程序结果相关的有限词表：

| 属性类型 | 示例 | 典型判定依据 |
|:---|:---|:---|
| Object identity | 必须使用螺钉 A | 部件兼容性、说明书 |
| Object state | 盖子必须关闭 | 视觉状态、后续先决条件 |
| Tool identity/class | 扳手或兼容工具 | 工具功能、人工确认 |
| Spatial relation | 部件必须插入槽内 | 几何和最终状态 |
| Temporal order | A 必须先于 B | prerequisite |
| Quantity | 加入一个/两个部件 | 计数和任务目标 |
| Duration/range | 加热达到区间 | 时间或状态阈值 |
| Action manner | 旋转而非直接拔出 | 安全或效果约束 |
| Hand/pose/viewpoint | 左右手、抓取姿态 | 常常是合法自由属性 |

每条规则保存为结构化 tuple：

\[
r=(step,\ attribute\_type,\ predicate,\ status,\ evidence,\ confidence).
\]

---

## 12. 数据与 gold specification

### 12.1 数据分工

| 数据集/来源 | 主要用途 | 注意事项 |
|:---|:---|:---|
| EgoPER | 错误检测基线、有限正常示范 | normal 主要覆盖步骤顺序变化；不能代表充分 hard normals |
| AMNAR 对应数据 | 多种正常动作表征基线 | implicit prototype 不等于显式 necessary/free/unknown |
| Assembly101 | 装配步骤、不同参与者和视角 | 需要额外筛选合法非典型执行 |
| IndustReal | 灵活执行顺序和组件状态 | 规模小，适合外部验证 |
| CaptainCook4D | 烹饪错误类型与多样动作 | 需人工确认合法变化与真实错误 |
| 任务手册/专家 | required 规则独立证据 | 不能由待测模型自动生成 gold |

### 12.2 Gold rule 构造

对选定的 20–40 个可审计步骤：

1. 先定义属性词表，不查看模型预测。
2. 两名领域标注者阅读任务说明并观看多个正常/错误实例。
3. 对每条候选规则标为 required、witnessed-free 或 unknown。
4. required 必须记录独立证据来源。
5. witnessed-free 必须链接至少一对属性不同、但结果均正确的实例。
6. 无充分证据一律标 unknown，不允许凭直觉补全。
7. 第三人仲裁冲突。

### 12.3 Hard-normal 与 true-error 测试集

测试集必须独立于规则归纳方法构建：

- **Hard normals：** 少见、偏离 canonical trace、但经人工确认目标和约束均满足；
- **True errors：** 明确违反必要对象、状态、顺序、数量或效果约束；
- **Ambiguous cases：** 人类也无法可靠判断，用于检验 abstention；
- **Ordinary normals：** 常见正确执行，用于基本 sanity check。

不能根据模型输出的属性词表去专门制造 hard normals，再用同一词表证明模型有效。应在模型开发前冻结构造协议和测试集合。

### 12.4 IAA 与数据门槛

报告：

- 三值 rule status 的 Fleiss' kappa 或 Krippendorff's alpha；
- hard-normal/true-error 的一致性；
- 属性定位的一致性；
- 每类属性和每种 rule status 的数量。

建议 pilot 门槛：

- rule status alpha \(\ge 0.67\)；
- hard-normal 与 error 判定 alpha \(\ge 0.75\)；
- 每种主要属性至少有足够的 required、free 和 unknown 实例；
- always-abstain 不得在主要指标上形成不可超越的伪优势。

---

## 13. 方法应包含的实质机制

建议方法名：

> **Evidence-Calibrated Typed Specification Induction（ECTSI）**

### 13.1 模块 A：Typed Candidate Extraction

- 从步骤文本、正常视频和状态变化中提取候选属性；
- 将自由文本约束规范化为有限类型 predicate；
- VLM 可以提出候选，但不能直接决定 gold status。

### 13.2 模块 B：Evidence Ledger

对每条候选规则累积不同来源证据：

- invariance evidence；
- valid variation evidence；
- negative/counterexample evidence；
- action-effect evidence；
- manual/semantic evidence；
- physical consistency evidence。

每种证据有来源标记、可靠度和独立性，不把多个同源描述误当成多份证据。

### 13.3 模块 C：Three-Way Posterior

学习：

\[
p(z_r \mid E_r), \quad z_r \in
\{\text{required},\text{witnessed-free},\text{unknown}\}.
\]

关键是：

- observed invariance 只能增加 required 的可能性，不能单独把它确定为 required；
- 有经确认的合法变化时，才能进入 witnessed-free；
- 证据冲突或覆盖不足时保持 unknown；
- 输出应被校准，而非只给离散标签。

### 13.4 模块 D：Selective Mistake Detector

将当前视频解析为属性事实，与规则后验比较：

- 高置信违反 required → Alarm；
- 改变 witnessed-free 且无其他冲突 → Pass；
- unknown 属性、感知不确定或规则冲突 → Abstain。

训练目标应联合：

- typed rule classification；
- evidence consistency；
- video-predicate grounding；
- selective risk；
- calibration。

---

## 14. Paper 2 的逐步实验路线

### 阶段 P2-0：先验证人是否能定义三值规范

**实验 0A：Rule IAA**

- 对 pilot 步骤进行独立三值标注；
- 按属性类型报告一致性；
- 分析 required/free、required/unknown 和 free/unknown 的主要冲突。

**要证明：** 三值规范是可复现任务，而不是研究者任意解释。

**实验 0B：Hard-normal IAA**

- 标注者独立判断候选非典型执行是否仍完成目标；
- 必须查看最终状态或明确的动作效果；
- 报告普通正常、hard normal、真错误和歧义样本的一致性。

**要证明：** “罕见但正确”样本真实存在且能够独立确认。

### 阶段 P2-1：建立强基线

| 基线 | 代表思想 | 为什么必须比较 |
|:---|:---|:---|
| Single prototype | 单一正常模板 | 检查多样正常性的必要性 |
| Multi-prototype / AMNAR | 多正常表征 | 最强 implicit normality 邻居 |
| EgoPER-style anomaly detector | 正常/错误判别 | 检查普通 PMD 能否解决 |
| AEM-style effect model | 动作结果状态 | 检查效果建模是否足够 |
| DTGL temporal rule | 程序图与顺序 | 检查显式步骤结构 |
| AXG-Reasoner | normal-only + subaction + explanation | 输出侧最近邻 |
| Prompted VLM | 视频帧 + 步骤说明 | 检查通用常识 |
| Bayesian specification inference | 规则后验 | 最接近 specification induction |
| Binary constrained/free | 无 unknown | 证明三值状态的必要性 |
| Always Alarm/Pass/Abstain | 平凡策略 | 防止指标被投机 |

所有可训练基线尽量共享冻结视频特征，并报告参数量和推理成本。

### 阶段 P2-2：主实验一——Invariant Quality

预测每条 gold rule 的三值 status。

主要指标：

- required precision、recall、F1；
- witnessed-free precision、recall、F1；
- Macro-F1；
- unknown calibration；
- Brier score 或 ECE；
- logical consistency violation rate；
- 按属性类型的性能；
- evidence attribution accuracy。

其中 required precision 比 required recall 更重要：把合法自由属性误判为 required，会直接制造误报。

**要证明：** ECTSI 能区分“稳定出现”“已证明可变”和“尚不知道”，而不是把所有未变化属性都标为必要。

### 阶段 P2-3：主实验二——Selective Mistake Detection

在 ordinary normal、hard normal、true error 和 ambiguous 四类样本上评估 `Alarm / Pass / Abstain`。

主要指标：

- error recall；
- hard-normal false-positive rate；
- balanced accuracy；
- selective risk–coverage curve；
- AURC；
- coverage at fixed target risk；
- error recall at matched hard-normal FPR；
- abstention precision：被拒答样本是否真的更难或更歧义。

**要证明：** 显式三值规则能够在保持错误召回的同时，显著减少对合法非典型执行的误报。

### 阶段 P2-4：决定性实验——Hard-normal False Alarm

构建 matched pairs：

- 相同步骤和任务目标；
- ordinary normal 与 rare-but-valid variant；
- 尽量匹配参与者、视角、时长和背景；
- 只改变一个或少数属性。

比较：

- binary anomaly detectors；
- multi-prototype normality；
- AEM effect model；
- prompted VLM；
- ECTSI。

**要证明：** 方法的优势不是普通正常视频上的准确率，而是能识别合法变化。

### 阶段 P2-5：Demo 数量与可识别性实验

对每个步骤使用 \(1,2,4,8,16,\ldots\) 个正常示范，绘制：

- required precision/recall；
- witnessed-free coverage；
- unknown 比例；
- hard-normal FPR；
- error recall；
- selective coverage。

必须同时画：

- always-abstain；
- 全部稳定属性均视为 required；
- binary required/free；
- ECTSI。

合理现象应是：

- 随示范增加，观察到更多合法变化，witnessed-free 增加；
- unknown 在获得独立证据后下降；
- required 不能仅因重复观察而无条件增加；
- hard-normal FPR 随证据改善而下降。

**要证明：** unknown 是对证据不足的校准表达，而不是用 abstention 隐藏错误。

### 阶段 P2-6：Abstention 是否只是投机

在相同 coverage 下比较所有方法的 risk；在相同 risk 下比较 coverage。

额外报告：

- ECTSI 与 always-abstain 的效用差；
- 错误召回—abstention rate 曲线；
- hard-normal FPR—error recall 曲线；
- 将 unknown 强制映射为 Alarm 或 Pass 后的结果；
- 每种属性类型的拒答比例。

**要证明：** 性能提升来自更好的知识边界，而不是简单少回答。

### 阶段 P2-7：独立证据的必要性

逐项加入证据：

1. positive-video invariance only；
2. + step text；
3. + valid variation pairs；
4. + action-effect evidence；
5. + negative examples；
6. + human/physical constraints；
7. 完整 evidence ledger。

**要证明：**

- positive-only invariance 无法可靠识别 required；
- valid variation 主要帮助 witnessed-free；
- negative/effect/semantic evidence主要帮助 required；
- evidence provenance 确实改善校准。

这是 Paper 2 最关键的机制实验。

### 阶段 P2-8：类型化表示是否必要

比较：

- 自由文本规则；
- 无类型二元 predicate；
- 统一 embedding；
- typed predicate + evidence ledger；
- typed predicate 但无 status uncertainty。

评估：

- rule F1；
- unseen attribute generalization；
- logical consistency；
- explanation faithfulness；
- hard-normal FPR。

**要证明：** 类型系统不是展示界面，而是改善组合泛化和约束一致性。

### 阶段 P2-9：跨属性、跨工具和跨任务泛化

建议 split：

- unseen object instance；
- unseen compatible tool；
- unseen valid ordering；
- unseen actor/handedness；
- unseen task，但共享属性类型；
- assembly → cooking 或反向迁移。

**要证明：** 方法学到可组合的属性规则，而不是记住步骤名称或视觉模板。

### 阶段 P2-10：视频 grounding 检验

比较：

1. step text only；
2. action label only；
3. sampled image/VLM；
4. full video feature；
5. video + effect/state；
6. 完整 ECTSI。

建立相同文本描述但实际对象状态不同的 hard pairs。

**要证明：** 模型确实从视频识别属性是否满足。若 text-only 与完整模型持平，该工作不够成为视频理解论文。

### 阶段 P2-11：核心消融

| 消融 | 检验内容 |
|:---|:---|
| 去掉 witnessed-free 状态 | 是否会把合法变化误报警 |
| 去掉 unknown 状态 | 是否产生过度自信 |
| 去掉证据来源标记 | 是否错误累计同源证据 |
| 去掉 valid-variation evidence | free 规则如何退化 |
| 去掉 negative/effect evidence | required 规则如何退化 |
| 去掉 typed predicates | 组合泛化是否下降 |
| 去掉 posterior calibration | selective risk 是否恶化 |
| 去掉 video grounding | 是否只靠文本常识 |
| VLM 候选替换人工候选 | 候选提取误差的影响 |

### 阶段 P2-12：解释忠实度

模型输出报警或拒答时，必须指出：

- 涉及哪个步骤；
- 哪种属性；
- 哪条规则；
- rule status 与置信度；
- 使用了哪些证据；
- 视频中的支持片段。

不要只用 LLM-as-judge。至少进行：

- rule deletion test：删除所引用规则后，决策是否按预期改变；
- evidence deletion test：遮蔽所引用片段后，置信度是否下降；
- predicate localization：人工检查所指对象/状态；
- 人类可验证性评分，报告 IAA；
- 错误解释与最终决策的一致率。

**要证明：** 解释反映模型实际决策依据，而不是事后生成的自然语言。

---

## 15. Paper 2 的主要结果表应如何组织

建议正文保留六个核心结果：

1. **表 1：Gold rules、hard normals 与 IAA**
   - 证明任务和标签可信。
2. **表 2：三值 invariant induction**
   - 证明 required/free/unknown 归纳质量。
3. **图 1：Selective risk–coverage**
   - 证明不是靠 always-abstain 获胜。
4. **表 3：Hard-normal FPR at matched error recall**
   - 证明解决了现有方法的核心误报。
5. **图 2：Demo-count/identifiability**
   - 证明证据增加时 unknown 和 free 的变化合理。
6. **表 4：Evidence 与 typed representation 消融**
   - 证明方法机制。

---

## 16. Paper 2 的致命风险

| 风险 | 如何检查 | 决策 |
|:---|:---|:---|
| required/free/unknown 人类也无法一致 | rule IAA pilot | 重定义；仍低则停题 |
| required 只来自模型或不变频率 | evidence provenance audit | 不允许进入 gold |
| hard normals 由方法自身词表构造 | 数据审计 | 必须独立重建 |
| 方法仅靠更多 abstention 获胜 | risk–coverage + always-abstain | 同 coverage 无优势则失败 |
| 显式规则不优于 AMNAR 等 implicit model | hard-normal 主实验 | 无稳定增益则核心主张失败 |
| text-only 与 video 模型持平 | grounding hard pairs | 无视觉贡献则不适合 CV 顶会 |
| unknown 吞掉大部分测试集 | demo-count curve | coverage 长期过低则任务不可用 |
| 规则解释不忠实 | deletion tests | 无因果响应则删除解释主张 |

---

## 17. Paper 2 的算力与时间预算

| 阶段 | 主要工作 | 预计资源 |
|:---|:---|:---|
| 词表与 pilot | gold rules、hard normals、IAA | 4–8 周，以人工为主 |
| 特征与 predicate 缓存 | 冻结视频/VLM 编码器 | 1 张 4090 |
| 三值归纳模型 | 轻量 Transformer/图模型 | 1 张 4090 |
| 主实验和消融 | 多证据组合与数据量消融 | 2 张 4090，约 20–35 GPU-days |
| VLM 候选抽取 | 7B 模型 4-bit LoRA 可选 | 1–2 张 4090 |
| 复现与跨域 | 主结果多随机种子 | 约 10–20 GPU-days |

主要成本仍然是规则和 hard-normal 的独立标注，不是训练。

---

# 18. 两篇论文的推荐执行顺序

## 阶段 A：共同基础设施，4–6 周

1. 统一下载、解析 Assembly101、IndustReal、CaptainCook4D 等公开标注。
2. 缓存统一视频特征。
3. 建立流式 clip/step 数据加载器。
4. 实现参与者、任务和多视角防泄漏 split。
5. 建立视频—步骤—物体状态—task graph 的统一 schema。
6. 复现 AMNAR/AEM/DTGL 类代表基线中的至少两类。

**里程碑：** 给定任意视频前缀，能够稳定输出步骤 token、视频状态 feature 和程序图节点。

## 阶段 B：同时做两个低成本 pilot，4–6 周

Paper 1 pilot：

- 200–300 个错误 episode；
- 源错误→受影响步骤、manifestation、return-to-valid 标注；
- 图规则、label-only 和 video-only 基线。

Paper 2 pilot：

- 20–40 个步骤；
- 三值规则和独立证据；
- hard-normal/true-error/ambiguous 小测试集；
- single prototype、multi-prototype 和 prompted VLM 基线。

**决策：** 哪个 pilot 先通过 stop/go，哪个先进入主论文开发。不要在标签可行性未知时并行投入两套大模型。

## 阶段 C：优先完成 Paper 1，约 4–6 个月

建议 Paper 1 先做，因为其问题更贴近当前 procedural mistake detection 主线，且可复用已有错误数据。

1. 冻结标注协议和 test split；
2. 扩充自然 propagation labels；
3. 完成 SCSR；
4. 做 affected-step 和 manifestation 主实验；
5. 做 video-vs-graph 决定性实验；
6. 做 budgeted risk-ranking utility；
7. 最后补 PIE-V 和跨域实验。

## 阶段 D：完成 Paper 2，约 5–7 个月

Paper 2 的 bottleneck 是 gold specification 和 hard-normal 质量，适合在 Paper 1 训练期间持续积累标注。

1. 冻结 typed vocabulary；
2. 建立独立 gold rules；
3. 冻结 hard-normal 测试；
4. 完成 ECTSI；
5. 做 invariant quality 和 selective detection；
6. 做 demo-count、always-abstain 和 evidence ablation；
7. 做跨属性与解释忠实度。

---

# 19. 投稿前的最小证据清单

## Paper 1 必须全部回答

- [ ] 新标签有可信 IAA。
- [ ] 主结果来自自然视频。
- [ ] 严格 prefix-only，无未来泄漏。
- [ ] affected-step 优于 graph descendants 和 Every Mistake Counts 规则。
- [ ] 完整视频模型优于 action-label-only。
- [ ] state delta 和 graph rollout 有稳定消融增益。
- [ ] manifestation hazard 的校准优于普通回归。
- [ ] unseen toy/task/error 上仍有增益。
- [ ] 在固定复核预算下优于当前错误分数排序。
- [ ] 清楚声明恢复时间是 observed-policy conditional，而非人的固有属性。

## Paper 2 必须全部回答

- [ ] required/free/unknown 有独立 gold 和可信 IAA。
- [ ] required 不是从 positive invariance 直接推出。
- [ ] hard normals 在方法开发前独立构造。
- [ ] 与 AMNAR、AEM、AXG/VLM 和 specification baseline 比较。
- [ ] 在 matched error recall 下显著降低 hard-normal FPR。
- [ ] 报告完整 risk–coverage 和 always-abstain。
- [ ] demo 数量增加时 unknown/free 的变化符合证据逻辑。
- [ ] typed representation 和 evidence ledger 均有独立增益。
- [ ] text-only 不足以完成任务。
- [ ] 解释通过 rule/evidence deletion faithfulness test。

---

# 20. 何时应放弃其中一篇

## 放弃或大改 Paper 1，当且仅当

- 传播关系无法被人稳定标注；
- 独立自然 propagation episode 数量不足；
- task graph 后继规则与完整视频模型持平；
- 下游后果无法在发生前预测；
- 有限预算排序不优于“按当前错误置信度排序”。

此时不要退回“预测谁会恢复”。更合理的降级方向是：

- 只做 persistent state discrepancy；
- 只做 affected-milestone localization；
- 或把成果作为 Paper 2 的 downstream application。

## 放弃或大改 Paper 2，当且仅当

- 人类无法稳定区分 required、free 和 unknown；
- 独立 hard-normal 样本无法获得；
- 显式规则不比 multi-prototype normality 更好；
- 所有优势都来自大比例 abstention；
- 视频证据不比步骤文本提供更多信息。

此时可降级为：

- hard-normal evaluation protocol；
- evidence-calibrated selective PMD；
- 或先作为分析工作积累数据，不急于声称完整 specification induction。

---

# 21. 最终优先级

如果只能先做一篇，建议按以下决策，而不是只看 idea 新颖度：

1. 先各投入一个小 pilot。
2. Paper 1 若能得到高一致性的自然传播标签，并且 video+graph 明显优于 graph-only，则先做 Paper 1。
3. Paper 2 若能获得高质量 hard normals，且 AMNAR 类模型在这些样本上确实高误报，则 Paper 2 的创新边界更干净，可先做 Paper 2。
4. 任一方向未通过 stop/go，都不要因为已经投入时间而继续堆模型。

从当前公开数据现实看：

- **Paper 1 的监督扩展工作量较大，但实际辅助价值更直观。**
- **Paper 2 的概念新颖性更强，但 gold rule 和 hard-normal 的独立性决定成败。**

因此合理策略是：**先做两个标注 pilot，再让证据决定投稿顺序。**

---

# 22. 本地主要证据

- [Assembly101](../003_Sener_Assembly101_A_Large-Scale_Multi-View_Video_Dataset_for_Understanding_Procedural_Activities_CVPR_2022_paper.pdf)
- [Every Mistake Counts in Assembly](../Every%20Mistake%20Counts%20in%20Assembly.pdf)
- [CaptainCook4D](../007_NeurIPS-2024-captaincook4d-a-dataset-for-understanding-errors-in-procedural-activities-Paper-Datasets_and_Benchmarks_Track.pdf)
- [IndustReal](../009_Schoonbeek_IndustReal_A_Dataset_for_Procedure_Step_Recognition_Handling_Execution_Errors_WACV_2024_paper.pdf)
- [DTGL](../008_NeurIPS-2024-differentiable-task-graph-learning-procedural-activity-representation-and-online-mistake-detection-from-egocentric-videos-Paper-Conference.pdf)
- [PIE-V / How to Correctly Make Mistakes](../016_Loginova_How_to_Correctly_Make_Mistakes_A_Framework_for_Constructing_and_CVPRW_2026_paper.pdf)
- [AMNAR](../023_Huang_Modeling_Multiple_Normal_Action_Representations_for_Error_Detection_in_Procedural_CVPR_2025_paper.pdf)
- [AEM](../019_Procedural%20Mistake%20Detection%20via%20Action%20Effect%20Modeling.pdf)
- [AXG-Reasoner](../017_Lee_AXG-Reasoner_Error_Detection_and_Explanation_in_Long_Task_Videos_with_CVPR_2026_paper.pdf)
- [项目内研究机会报告](./research_opportunity_report.md)

## 尚需在正式开题前核验

- 各数据集当前许可证是否允许重新发布派生标注；
- Assembly101 自然错误中可独立标注传播链的实际数量；
- CaptainCook4D 中具有可靠源错误时间段的可用子集；
- hard-normal 的招募、筛选和专家确认成本；
- 2026 年下半年至投稿截止日前是否出现直接同题工作；
- 所有 2026 预印本在正式引用时的最终题名、版本和发表状态。
