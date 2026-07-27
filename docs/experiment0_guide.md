# 实验 0 操作指南（初学者版）

> 生成时间：2026-07-27
> 目的：验证「现有 SOTA 在合法但非典型的执行上会误报」——这是整篇论文的立论基础。
> 若结论不成立，idea 作废，不要继续写代码。

---

## 0 先看这里：算力安排

本机实际硬件：

```
NVIDIA GeForce RTX 2060, 6144 MiB   ← 6GB 显存
Python 3.12.3 / conda 24.9.2 / git 2.55.0
```

你已决定**租用平台 GPU**。这是正确的选择——6GB 走不完这个课题。但关键是**什么时候租**，因为租赁按小时计费，而实验 0 里最耗时的那一步根本不需要 GPU。

### 各步骤的算力需求

| 步骤 | 需要 GPU 吗 | 在哪做 |
|---|---|---|
| 第 1 步 建环境 | 需要（验证 CUDA） | 租的机器上 |
| 第 2 步 下数据/权重 | ❌ 不需要 | 见下方"省钱要点" |
| 第 3 步 跑通推理 | ✅ 需要 | 租的机器 |
| **第 4 步 造 hard normal** | ❌ **完全不需要**（人工看视频） | **本机，不开租用** |
| 第 5 步 跑对比 | ✅ 需要 | 租的机器 |
| 第 6 节 VLM 对照 | ❌ 不需要（走 API） | 本机 |

**第 4 步是全实验最耗时的（2–3 天），而它是纯人工标注工作。** 这几天千万不要挂着 GPU 计费。

### 租什么规格

| 阶段 | 建议 | 理由 |
|---|---|---|
| 实验 0（只推理） | **单卡 3090 / 4090，24GB** | 推理够用，最便宜 |
| 后续训练归纳器 | 单卡 24GB | 符号模块 + 小头，<8GB 就够 |
| 后续 7B VLM 属性抽取 | 单卡 24GB（bf16） | 20GB 左右，24GB 卡刚好 |

**不需要 A100/H100。** 这个课题全程是"冻结特征 + 小模型"，和 EgoPER/AMNAR 的算力量级一致。花钱租大卡是浪费。

### 省钱要点（初学者最容易在这里烧钱）

1. **数据下载不要占用 GPU 计费时间。** 很多平台的数据盘可以在不开机（或开 CPU-only 实例）的状态下传输，价格低一个数量级。先查你的平台有没有这个功能。
2. **环境配好后立刻存镜像/快照。** 否则每次开机都要重装 torch 和依赖，几十分钟白烧。
3. **数据放持久化存储**，不要放系统盘。关机后系统盘常被清空，重下一遍 EgoPER 很痛。
4. **按量付费先跑通，再考虑包月。** 实验 0 总 GPU 时间大概 1–2 天，按量更划算。
5. **随时确认关机。** 忘关是最常见的浪费。

### 选镜像时的坑

AMNAR 的 `requirements.txt` 锁定 `torch==2.0.0` + CUDA 11.7。租赁平台默认镜像现在多是 CUDA 12.x，直接装会有兼容问题。

两个办法：
- **选镜像时挑 CUDA 11.7 或 11.8 的**（推荐，最省事）
- 或者装 cu118 版本的 torch：`pip install torch==2.0.0 --index-url https://download.pytorch.org/whl/cu118`

另外 `torch 2.0.0` **不支持 Python 3.12**（本机是 3.12），必须建 Python 3.10 的 conda 环境。下面命令里已经写好了。

---

## 1 实验 0 到底要验证什么（用大白话讲一遍）

现有的错误检测模型，判断依据本质上是「这段视频像不像我训练时见过的正确执行」。不像 → 报警。

问题是：**「不像」有两种原因**
1. 用户真的做错了（该报警）
2. 用户用了一种模型没见过但完全正确的做法——换了把扳手、换只手、把两个无关的子步骤对调（**不该报警**）

现有评测集里第 2 类几乎不存在，所以没人发现模型会在这里翻车。

**实验 0 就是把第 2 类样本喂给现有的 SOTA，看它报不报警。**

- 如果它大量误报 → 问题真实存在，你的论文有的可写，而且这张图是**用别人的模型**证明的，比你自己论述有力得多。
- 如果它不误报 → 现有方法已经能处理，你的论文没有问题可解，**立刻止损**。

我们把第 2 类样本叫 **hard normal**（"困难的正常样本"）。

---

## 2 术语速查（初学者可能卡住的地方）

| 术语 | 意思 |
|---|---|
| FAR (False Alarm Rate) | 误报率 = 在**正常**样本中被判成错误的比例。本实验的核心指标 |
| hard normal | 合法但非典型的执行（换工具/换手/合法顺序变动） |
| easy normal | 数据集里原有的普通正常样本（典型做法） |
| baseline | 用来对比的现有方法，这里是 AMNAR 和 EgoPER |
| checkpoint / 权重 (.pth) | 训练好的模型参数文件，加载后可直接推理，不用自己训 |
| 推理 (inference) | 只用模型做预测，不更新参数。省显存 |
| TAS (Temporal Action Segmentation) | 时序动作分割，把长视频切成一个个动作段。AMNAR 的第一阶段 |
| EDA / AUC | 该领域常用指标。本实验不用它们，只看 FAR |

---

## 3 实验 0 的核心逻辑：对比两个数字

对同一个模型、同一套权重、同一个阈值，测两次：

```
FAR_easy  = 在数据集原有正常样本上的误报率
FAR_hard  = 在 hard normal 样本上的误报率
```

**判据**：`FAR_hard` 是否显著高于 `FAR_easy`。

这个设计的好处是**它是自对照的**——同一个模型同一个阈值，唯一变量是样本类型。你不需要跟任何论文里的数字对齐，也不用担心复现精度差一点点。这对初学者非常友好。

> 常见误解：不需要让 AMNAR 复现出论文里的 EDA/AUC 数值。只要模型能正常跑出预测就行。数值对不上不影响实验 0 的结论。

---

## 4 分步操作

### 第 1 步：建环境（约 1 小时）

```bash
# 建 Python 3.10 环境（不能用 3.12，torch 2.0.0 不支持）
conda create -n amnar python=3.10 -y
conda activate amnar

# 装 torch（CUDA 11.7 版，对应 requirements.txt）
pip install torch==2.0.0 torchvision==0.15.1 torchaudio==2.0.1 --index-url https://download.pytorch.org/whl/cu117

# 验证 GPU 可用
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

最后一行必须打印出 `True` 和 `NVIDIA GeForce RTX 2060`。如果是 `False`，先解决驱动问题再往下走。

```bash
# 拉代码（注意默认分支是 master，不是 main）
cd /d/paperscode/fx3
git clone https://github.com/iSEE-Laboratory/AMNAR.git
cd AMNAR
pip install -r requirements.txt
```

> `requirements.txt` 里那些 `nvidia-cuda-*` 条目如果报错可以忽略，torch 已经自带。

### 第 2 步：下数据和权重（约半天，看网速）

**EgoPER 数据集**：从 [EgoPER_official](https://github.com/robert80203/EgoPER_official) 下载。

重要：**只下 `tea` 这一个 task 就够了**。README 的示例全用 tea，而且单 task 数据量小得多。全部下完是浪费。

目录结构必须长这样（README 原文）：

```
EgoPER/
├── tea
│   ├── features_10fps_dinov2      ← 预抽取特征，这个是关键
│   ├── features_10fps_new
│   ├── frames_10fps_new
│   ├── test.txt
│   ├── training.txt
│   ├── trim_start_end.txt
│   ├── trim_videos
│   └── validation.txt
```

> **优先下 `features_*` 而不是 `frames_*`/`trim_videos`**。特征是预先抽好的，推理直接用，省时间省显存。原始帧和视频体积大得多，实验 0 用不上（除了第 3 步你要肉眼看片段时需要）。

**AMNAR 权重**：作者提供了 [Google Drive](https://drive.google.com/drive/folders/1DrnDhNWq1MDmtFpjwOMz_VuQo5PeAD_a?usp=sharing)。下 tea 相关的那份，放到 `./ckpt/EgoPER/` 下。

**用权重不要自己训练**——6GB 显存训不动，而且实验 0 不需要。

### 第 3 步：先跑通原版推理（约半天）

在碰 hard normal 之前，先确认整条管线能跑。README 的三条命令按顺序执行（配置文件名很长，直接复制）：

```bash
# 3a. 动作分割
python test.py ./configs/EgoPER/tea_aod_rebuild_ca_sigt_online_clusterCenter_it0.6_addedMax_norm_unfreeze_winlen32_dila3_dilaLayer5_fr5_cu10_cus0.40_m0.9_dp0.1_e200.yaml ./ckpt/EgoPER/tea_aod_rebuild_ca_sigt_online_clusterCenter_it0.6_addedMax_norm_unfreeze_winlen32_dila3_dilaLayer5_fr5_cu10_cus0.40_m0.9_dp0.1_e200_1st

# 3b. 错误检测
python test_ed.py ./configs/EgoPER/tea_aod_rebuild_ca_sigt_online_clusterCenter_it0.6_addedMax_norm_unfreeze_winlen32_dila3_dilaLayer5_fr5_cu10_cus0.40_m0.9_dp0.1_e200.yaml ./ckpt/EgoPER/tea_aod_rebuild_ca_sigt_online_clusterCenter_it0.6_addedMax_norm_unfreeze_winlen32_dila3_dilaLayer5_fr5_cu10_cus0.40_m0.9_dp0.1_e200_1st

# 3c. 算指标
python metric_vis_multiprocess.py --task tea --dirname tea_aod_rebuild_ca_sigt_online_clusterCenter_it0.6_addedMax_norm_unfreeze_winlen32_dila3_dilaLayer5_fr5_cu10_cus0.40_m0.9_dp0.1_e200_1st/ -as -ed
```

参考 `run_sh_EgoPER/` 里那个 `.sh` 脚本，有更多示例。

**这一步的目标**：能跑出数字。数字跟论文对不上没关系（见 §3 的说明）。

**如果 OOM**：找配置文件里的 `batch_size` 改成 1。推理时 batch 小不影响结果。

**这一步要记下的东西**：模型在哪里输出「这一段是错误」的判定，以及判定用的阈值在哪个文件/参数里。后面第 5 步要复用同一个阈值。

### 第 4 步：造 hard normal（最关键，约 2–3 天）

这一步是全实验的核心，也是最容易做错的地方。

#### 4a. 从哪里找

**不要从 EgoPER 找 hard normal。** 原因是 EgoPER 原文 Sec. 3.1 写了：

> "the execution of each step follows the specific description of the step"

意思是它的正常视频里，step 内部的执行方式**被刻意统一了**，非典型执行按构造就不存在。而且它把「换工具」直接定义成错误：

> "some steps are modified (e.g., **using a different tool** or different ingredients...)"

所以在 EgoPER 里你找不到 hard normal，只找得到被它标成"错误"的 modification。

**去 HoloAssist（222 名参与者）或 Assembly101（53 名参与者）找。** 人多才有自然变异。

| 数据集 | 参与者数 | 适合做 hard-normal 源 |
|---|---|---|
| HoloAssist | 222 | ✅ 最好 |
| Assembly101 | 53 | ✅ 好 |
| EgoPER | 11 | ❌ 且执行被统一 |
| CaptainCook4D | 8 | ❌ |

#### 4b. 怎么筛（顺序不能变）

**先筛，后分类。** 这个顺序是硬性的，颠倒了就是循环论证（等于"我按自己的标准造题，再证明自己能做对"）。

1. **盲筛**：找出「跟这个 step 的常见做法明显不一样，但确实成功完成了」的片段。
   - 筛的时候**不要想属性类型**（工具/手/顺序），只凭"这做法挺特别但没错"的直觉。
   - 如果有同学帮忙，让他们筛，且**不要告诉他们你的方法细节**。

2. **确认正确性**：每个候选片段找 ≥3 个人独立判断「这算不算成功完成了这一步」。只留多数认为正确的。

3. **记一致性**：记录 3 个人的判断是否一致。不一致的片段单独放一堆，不混进主集。
   - 论文里要报 Fleiss' κ 或 Krippendorff's α。**现在先把原始判断记下来就行**，指标后面算。
   - 为什么必须做：领域综述已经承认，标注者对「什么算可容许变异、什么算错误」本身就有分歧。不报一致性，你的整个指标会被质疑成主观构造。

4. **最后才分类**：筛完了，才给每个片段贴标签（未见工具 / 换手 / 合法顺序变动 / 未见环境）。这个标签只用于后面分维度分析。

5. **查泄漏**：hard normal 的参与者不能和模型训练用的正常样本是同一批人、同一场录制。

#### 4c. 数量目标

**实验 0 阶段：先攒 30–50 个就够看出趋势。** 别一开始就想凑几百个。

但同时要做一件事：**记录你筛一个 task 花了多久、得到多少个**，用这个外推「全部数据集能得到多少」。

> 这条外推很重要。如果最后总量只有 100–200 个，CVPR 会认为评测规模是玩具级的。这个数字现在完全未知，而它比方法本身更可能决定成败。

#### 4d. 一个现实问题

hard normal 来自 HoloAssist/Assembly101，但 AMNAR 权重是在 EgoPER 上训的。**跨数据集直接推理，模型会因为"域不同"而误报**，这跟"因为执行非典型而误报"混在一起了。

两个解法，选一个：

- **解法 A（推荐给初学者）**：在同一个数据集内部对比。从 HoloAssist 里同时取 easy normal 和 hard normal，用 AMNAR 在 HoloAssist 上的配置跑。AMNAR 支持 HoloAssist（README 的数据下载列表里有）。
- **解法 B**：仍用 EgoPER 权重，但 easy normal 也取自 HoloAssist。这样两边的域差是一样的，差异就只来自"典型 vs 非典型"。

**关键原则：`FAR_easy` 和 `FAR_hard` 必须来自同一个数据集、同一个模型、同一个阈值。** 只有这样两个数字才可比。

### 第 5 步：跑对比并记录（约 1 天）

```
对 easy normal 集跑推理 → 记 FAR_easy
对 hard normal 集跑推理 → 记 FAR_hard
（同一权重、同一阈值，不要调参）
```

**结果表模板**：

| 模型 | 数据集 | FAR_easy | FAR_hard | 差值 |
|---|---|---|---|---|
| AMNAR | HoloAssist | ? | ? | ? |
| EgoPER | HoloAssist | ? | ? | ? |

**同时记录**：`FAR_hard` 里那些被误报的片段，分别属于哪一类（换工具/换手/顺序）。这个分布会直接变成论文里的一张图。

---

## 5 判据与止损线

| 结果 | 含义 | 下一步 |
|---|---|---|
| `FAR_hard` 显著高于 `FAR_easy` | 问题真实存在 | ✅ 继续。这是 Figure 1 |
| 两者接近 | 现有方法已能处理 | ❌ **止损**，不要写代码 |
| 两者都很高 | 模型/环境有问题，不是发现 | 回第 3 步排查 |

「显著」怎么判：初学者阶段先看绝对差距（比如 15% vs 45%）。样本量小的时候可以做个简单的比例检验（如 Fisher exact test），但先看趋势即可。

---

## 6 同期必须做的第二件事：VLM 对照

**这个不能留到最后。**

审稿人必然会问：直接把 5 个正确执行 + 1 个测试片段丢给一个大模型，问它「这是错误还是合法的不同做法」，效果如何？

而且大模型在这件事上**天生有优势**——「换把扳手拧螺母算不算错」是常识问题。已经有工作（ZeProM）报告零样本 VLM 在程序错误检测上接近甚至匹配监督方法。

**如果 VLM 拿到大部分收益，你那套符号机制就失去存在理由。** 必须现在就知道这个数字。

做法（6GB 显存跑不了本地大模型，用 API）：
- 拿第 4 步筛出的 hard normal，抽几帧
- 连同同一 step 的几个正确示范帧，一起丢给 GPT-4o / Qwen-VL API
- 问「这是错误还是合法的不同做法」
- 记准确率

如果 VLM 很强，你的定位要转向它做不到的事：**校准的弃权**、**可读可复用的规范**、**跨任务迁移**（VLM 每次都从头判断，不积累规范）。

---

## 7 时间安排与 GPU 计费窗口

| 阶段 | 内容 | 预计 | GPU 开着吗 |
|---|---|---|---|
| 第 1 步 | 建环境 + 存镜像 | 1 小时 | ✅ 开 |
| 第 2 步 | 下数据 + 权重 | 半天~1 天 | ⚠️ 尽量用 CPU-only / 数据传输模式 |
| 第 3 步 | 跑通原版推理 | 半天~1 天 | ✅ 开 |
| 第 4 步 | 造 hard normal | **2–3 天（核心）** | ❌ **关机，纯人工** |
| 第 5 步 | 跑对比记结果 | 1 天 | ✅ 开 |
| 第 6 节 | VLM 对照 | 1 天 | ❌ 关机，走 API |

一周左右，但**实际 GPU 计费时间只有 2–3 天**。第 4 步最耗时也最关键，不要压缩，同时记得那几天把机器关掉。

建议的节奏：第 1–3 步连着做完（一次开机），关机；第 4 步在本机慢慢筛；筛够了再开机跑第 5 步。

---

## 8 初学者最容易踩的坑

1. **想复现论文数值** —— 不需要。实验 0 是自对照，数值对不上不影响结论。
2. **用 Python 3.12** —— torch 2.0.0 不支持，必须建 3.10 的 conda 环境。
3. **克隆时用 `main` 分支** —— AMNAR 默认分支是 **`master`**，`main` 上没有 README。
4. **下全部数据集** —— 只下 tea 一个 task。
5. **自己训练模型** —— 6GB 训不动，用作者权重。
6. **从 EgoPER 找 hard normal** —— 它按构造就没有（见 §4a）。
7. **先分类再筛选** —— 循环论证，顺序必须是先盲筛后分类。
8. **easy 和 hard 用不同阈值** —— 两个数字就不可比了。
9. **跨数据集比 FAR** —— 域差会污染结论，见 §4d。
10. **忘记记标注一致性** —— 补不回来，当时就要记。

---

## 9 卡住时怎么办

- **环境/依赖报错**：AMNAR 基于 [ActionFormer](https://github.com/happyharrycn/actionformer_release) 和 [EgoPER_official](https://github.com/robert80203/EgoPER_official)，README 明确建议先读这两个仓库。它们的 issue 区能搜到大部分环境问题。
- **OOM**：配置里 `batch_size` 调 1；确认在推理而不是训练。
- **数据路径错**：对照 §4a 的目录结构逐层检查，AMNAR 对路径格式敏感。
- **跑通了但结果诡异**：先确认第 3 步的原版推理是正常的，再怀疑 hard normal 部分。

---

## 10 这一步之后

实验 0 通过后，还有三个验证要做（都在方法实现之前）：

1. **属性抽取精度** —— 手标 100–200 个 step，量 VLM 的属性抽取准确率。低于 80% 要改设计。（前例不乐观：有工作报告 GPT-4o 在类似任务上仅 48.4%）
2. **三值比例区间** —— 估 `unknown` 随示范数的收缩速率。若 20 个示范时仍 80% unknown，方法不可用。
3. **hard normal 总规模外推** —— 见 §4c。

这三个里第 1 个需要 GPU（跑 7B VLM，24GB 卡 bf16），第 2、3 个基本不需要。同样按需开机。

---

> 详细的 idea 设计见 `docs/idea_report_C.md`，调研过程与占位判定见 `docs/conversation_export.md`。
