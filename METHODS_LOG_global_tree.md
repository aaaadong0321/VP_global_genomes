# METHODS_LOG — 全球跨 ST *Vibrio parahaemolyticus* 系统发育树（"全球背景定位"树）

> **状态**：方法学规划草案 v0.1（2026-06-01）。**本文件只做方法与参数规划，不含任何脚本/命令。**

---

## 决策更新 2026-06-03（实测 + 拍板）

**① 株数实测（NCBI Datasets v18，去重 GenBank/GCA 为全集）：**
- VP 基因组总数（去重）= **15,383**（GCA 15,383 + RefSeq 副本 GCF 4,309）。
- 有采样年份 14,307；**缺采样年份 1,076（7%）**（D7 待定）。
- **采样年份 2019+ = 6,216**（逐年 2019:785 / 20:808 / 21:1237 / 22:892 / 23:1102 / 24:841 / 25:459 / 26:92）。释放年份 2019+ = 14,525（不作筛选口径）。
- 国家偏态：China 2,629 + USA 2,398 = 2019+ 的 **81%**；其余 Australia 332、NZ 290、UK 97、Vietnam 76…
- **含义**：6,216 > 4–5k 目标且重偏 China/USA → **D2 降采样从"可选"变"必须"**；6,216 为 **QC 前毛数**（ANI 物种确认 + 组装 QC 后会缩）；**NCBI 元数据不含 ST，"全 ST 分布"需另跑 mlst 或查 PubMLST（未做）**。

**② D1 拍板 = assembly**（reads/assembly 走 assembly）。reads 路线因公共株多无 reads + 2–7 TB 存储正式排除。

**③ 比对器拍板 = MUMmer→RIMD（Yang 路线），先复刻。**
- **库内 `U72LA3KE` = Yang 2019, *ISME J* 13:2578（"Recent mixing…"），1,103 株，SOAPdenovo → MUMmer→RIMD → FastTree2。**
- **8,684 株那篇 = 库内 `U5WDYDMI` = Yang 2025, *Nat Ecol Evol*（"Wave succession…"）。**

**④ Yang 2025 全文 Methods 已读并核实（2026-06-03，[高]）—— 全球树流程与本草稿实质一致：**
- assembly（shovill v1.1.0）→ **MUMmer v3.23** → RIMD2210633（NC_004603.1/NC_004605.1）→ **SNP-sites v2.5.1** 取 **core = >99% present** 的 SNP → TRF v4.07b + BLASTN 去重复 → **FastTree v2.1.10（全部 8,684 株）**。
- QC：**CheckM v1.1.3 + fastANI v1.1**，阈值 completeness>90% / contam<5% / **ANI>95%**。
- **Gubbins v3.1.3 + RAxML-NG v1.0.1（GTR+Γ）只用于克隆子集（pre-PC/PC）做重组剥离+dating，不用于全树** → **双重证实"全球树不掩蔽"决策**（Yang 2019 + 2025 都如此）。
- 降采样先例：**同国家同年内 ≤6 SNP 的簇取 N50 最大株** → 942 代表株（与本草稿 ST×国家×年份分层同源）。
- **要据实修正的精度点（非硬伤，已写进 REVIEWED.docx 修订）**：(a) Yang2025 用 MUMmer **v3.23**（Delcher 2003），非草稿引的 MUMmer4（Marçais 2018）；(b) QC 是 CheckM v1.1.3 / fastANI v1.1,非 CheckM2/skani。用新工具 OK,但措辞应为"升级"而非"复刻"。**(c) D3 core 阈值有了锚点 = >99%。**

**审核产出**：`~/Desktop/METHODS_global_tree_formal_draft_REVIEWED.docx`（Word 原生 Track Changes，10 处 ins + 2 处 del + 4 条批注；reject 全部 = 逐字还原原文,已机器验证）。

**下一步建议**：决定 ST 分布走 mlst-on-assembly 还是 PubMLST → 定 D7（缺年份株）→ 库外工具引用过一遍 `/ars-citation-check` → 修 Yang2025 参考年份/卷页（Zotero 2025/pp.1-13 vs 草稿 2026;10:416-428）。
> **作者分工**：Claude 起草；所有**科学判断点保留给你（和 Charles）拍板**，文中凡涉及取舍处均列"选项 + 利弊 + 我的倾向 + 需拍板"，不替你下结论。

---

## 0. 范围、设计与来源约定

### 0.1 这棵树的定位
- **目标**：~4000–5000 株、2019 至今、**全 ST** 的 *V. parahaemolyticus*（VP）系统发育树。
- **唯一职责**：**全球背景定位**——把你的 ST50 放进全球 VP 多样性框架里，看它在物种层级树上的位置/邻居/分支归属。
- **不承担**的论点：**地理/时间论点由另一棵 ST50-only 树承担**（该树有完整时间跨度）。因此本树**不需要严格分子钟、不需要做 dating、不需要 R_e**——这一点会反复影响下面多个方法选择（尤其是重组掩蔽和 bootstrap 的必要性）。

### 0.2 引用来源标签（全文统一）
| 标签 | 含义 |
|---|---|
| **【库内】** | 在你的 Zotero 库中，已读全文 Methods 核实支持该点（附 item key） |
| **【库内·仅摘要】** | 在库中，但我只用标题/摘要判断相关，**未读全文核实**——引用前需你/我补读 |
| **【网络】** | 网络来源，**不在你库**（方法学工具论文你库里基本没有） |
| **【skill标准】** | 来自本次加载的 phylogenetics / variant-calling / epidemiological-genomics skill |
| **【背景知识】** | 我的背景知识，无具体出处，**需独立核实** |

> **重要诚实声明**：你的 Zotero 库**富含 VP 生物学/流行病学文献，但几乎没有通用系统发育方法学/工具论文**。我对 Snippy、Gubbins、ClonalFrameML、FastTree、IQ-TREE、Treemmer、Parsnp 等做了语义检索，**相似度均为负值/接近零 = 库里没有**。这些工具的依据只能来自 skill 标准 + 网络，已如实标注，不会伪装成库内引用。

### 0.3 置信度约定
每个判断标 **[高/中/低]** 置信度。涉及你数据集实测的数字（如株数、core 大小）置信度天然偏低，已注明。

---

## 第一步：对齐模板 —— Yang 那篇的 Methods 逐条提取

### 1.1 已定位的"Yang 那篇"
**【库内】** Yang C, Li Y, …, Cui Y, Hu Q. **"Outbreak dynamics of foodborne pathogen *Vibrio parahaemolyticus* over a seventeen year period implies hidden reservoirs."** *Nature Microbiology* 7:1221–1229 (2022). DOI 10.1038/s41564-022-01182-0. **Zotero key `64IARYIZ`**。摘要"large-scale phylogenomic analysis of **3,642 isolates**"与你描述的 ~3600+ 株、Snippy→RIMD 完全吻合。**已读全文 Methods。**

### 1.2 Yang 2022 Methods 逐条提取（已全文核实，[高]）

| 方法点 | Yang 2022 的实际做法 |
|---|---|
| **数据类型** | **混合**：原始 Illumina reads（HiSeq X-Ten，PE150，~1.5 Gb clean reads/株）用于 SNP calling；**组装**基因组用于 MLST。 |
| **样本数与筛选** | 3,642 株；深圳**单城** 2002–2018 **全部存档** VP 分离株。**未做降采样、未排除任何数据**（"No statistical method was used to predetermine sample size. No data were excluded"）。 |
| **Reference** | **RIMD 2210633**（即你说的 Snippy→RIMD）。 |
| **SNP calling** | **Snippy v4.6.0**，core-genome SNP。 |
| **core 定义** | core = 出现在 **>99.5%** 株中的区域。 |
| **重复区处理** | 参考基因组重复区用 **Tandem Repeats Finder (TRF) v4.07b + BLASTN 自比对**识别并剔除，只用 **non-repetitive core-SNP**。 |
| **重组处理** | **Gubbins v2.3.4 只用在 FDOS-outbreak（克隆型暴发）株内**识别重组区——**不是对 3,642 株全树跑**。（对你的"不跑 Gubbins"判断关键，见第七步） |
| **建树方法** | **3,642 株全树 = FastTree v2.1.10**；只有更小的 cross-district Ob-cluster 子集用 **IQ-TREE v2.0.3**（auto best-fit model）；P-cluster 的最小生成树用 GrapeTree v1.5.0。 |
| **bootstrap** | 全树（FastTree）**未提 bootstrap/UFBoot**；IQ-TREE 子树用默认。 |
| **聚类阈值** | CG ≤2,500 SNP；P-cluster ≤6 SNP；同一暴发内 >100 SNP 的 outlier 排除。 |
| **MLST** | `tseemann/mlst` 扫组装基因组 vs PubMLST VP scheme。 |
| **时间分析** | TempEst v1.5.3 + BEAST v1.10.4（GTR+Γ；strict/relaxed clock × constant/skyline 比选）。 |
| **未在正文给出的 QC** | "genome quality assessment process shown in Extended Data Fig. 10"——正文无 QC 工具细节（需查附图）。 |

### 1.3 模板对齐的关键警示 [高]
**Yang 2022 是"深圳单城、低分歧、reads 齐备"的数据集；它用 reads+Snippy+FastTree、且未降采样。** 你的目标数据集是**全球、跨全 ST（深分歧）、以公共基因组为主**——条件与 2022 不同。这意味着直接套 2022 的 Snippy→RIMD 不一定是 Yang 团队自己在"全球跨 ST"场景下的做法（见第二步 Yang 2019）。

---

## 第二步：扩展文献交叉参照

### 2.1 最关键的库内交叉参照 —— Yang 2019（全球跨 ST，已全文核实）[高]
**【库内】** Yang C, …, Falush D, Cui Y. **"Recent mixing of *Vibrio parahaemolyticus* populations."** *ISME J* 13:2578–2588 (2019). **Zotero key `U72LA3KE`**。这是 **Yang/Cui/Falush 团队自己做的全球跨 ST VP 系统发育**（1103 株、4 个群体 VppAsia/VppX/VppUS1/VppUS2）——**比 2022 更贴近你的设计**。

| 方法点 | Yang 2019 的做法（全球跨 ST 场景） | 对你的意义 |
|---|---|---|
| **数据类型** | 392 新测 + 711 NCBI 公共；**全部走组装**（SOAPdenovo v2.04） | 全球场景下他们用 **assembly**，不是 reads |
| **SNP calling** | **MUMmer** 把基因组比对到 **RIMD 2210633**，只取 core 内 bi-allelic SNP；core = 出现在**所有**株中 | 跨 ST 用的是 **assembly + 全基因组比对**，**不是 Snippy-on-reads** |
| **core 随株数缩小（关键 scaling 事实）** | 1103 株 → 2.4 Mb core / 462,214 SNP；469 非冗余 → 3.3 Mb core / 650,683 SNP | **株越多、跨 ST 越广，core 越小、可用 SNP 越少**——你 4–5k 全 ST 的核心取舍 |
| **reference 稳健性** | 另测 FDA-R31、10329 两个参考 → core 大小(2.38/2.39 Mb)、SNP 数、树拓扑、群体分布**都相似** | **直接支撑"RIMD 可用、参考选择对结论稳健"** |
| **建树** | **FastTree 2**（默认参数，concatenated SNP）+ TreeBest NJ；iTOL 可视化 | 全球跨 ST 树用 FastTree 2，与 2022 一致 |
| **降采样/去冗余** | 迭代去冗余：随机移除互相 <2000 SNP 的株 → 469 非冗余集；再迭代到 260 跑 fineSTRUCTURE；并用 2 个独立随机化验证可重复 | **"在过度代表类群内部按距离去冗余"而非砍整个 ST 的直接先例** |

> **交叉参照结论 [高]**：你"按 ST/国家/年份在过度代表类群内部降采样"的思路，**与 Yang 2019 的去冗余策略同源**；而你"主要跟 Yang Snippy→RIMD"的模板，其实来自**不同场景（单城）**的 2022。**全球跨 ST 的 reads-vs-assembly 取舍因此不是纯算力问题，而是"该套用哪个 Yang 模板"的问题**（详见第三步 c）。

### 2.2 其他库内交叉参照（标注核实程度）
| 文献 | key | 支撑的方法点 | 核实程度 |
|---|---|---|---|
| Gonzalez-Escalona 2017, *Defining a cgMLST Scheme for Global Epidemiology of VP*, J Clin Microbiol | `SVREUT64` | 提供 VP **cgMLST 方案**（PubMLST/BIGSdb），是核心基因组分型的替代/补充路径；定义"全球 VP 流行病学"分型单位 | 【库内·仅摘要】 |
| Tsang 2017, *Failure of phylogeny inferred from MLST to represent bacterial phylogeny* | `9DQP3AJM` | 支撑"**不能用 MLST/ST 本身当系统发育**，需建全基因组/core-SNP 树"——即为什么要做这棵 WGS 树 | 【库内·仅摘要】 |
| Martinez-Urtaza 2026, *From clonality to complexity* | `L85VRICU` | VP 处于**克隆↔重组连续谱**；为"跨 ST 深分歧下重组普遍、clonal frame 不成立"提供概念支撑（关系到不跑 Gubbins） | 【库内·仅摘要】 |
| Urhan & Abeel 2021, *Comparative study of pan-genome methods…* | `37P4YEY2` | **单一线性参考引入 reference-bias**——RIMD 单参考的局限性提示 | 【库内·仅摘要】 |
| Jesser 2019, *Clustering of VP Isolates Using MLST and WGS Phylogenetics* | `VLV89EP8` | VP 中 MLST 与 WGS 系统发育聚类的关系 | 【库内·仅摘要】 |
| Campbell 2024, *Evolutionary dynamics of pandemic VP ST3 in Latin America* | `HXLPQEHE` | Martinez-Urtaza 组的 VP 谱系扩张系统发育（单 ST 深挖范例，可参照 ST50-only 树） | 【库内·仅摘要】 |
| Yang 2025, *Wave succession in the pandemic clone of VP driven by gene loss* | `U5WDYDMI` | Yang 组最新大规模 VP 系统发育（方法可能更新，值得补读其 Methods 对齐最新做法） | 【库内·仅摘要】 |
| QUAST-LG (Mikheenko 2018) | `TM8NXY46` | 组装 **QC**（contiguity/质量） | 【库内·仅摘要】 |
| BUSCO update (Manni 2021) | `VZP58Q8U` | 基因组**完整性**评估 | 【库内·仅摘要】 |
| Wick, Judd, Holt 2023, *Assembling the perfect bacterial genome* | `A25DFNYU` | 组装质量参考（主要针对长读，部分适用） | 【库内·仅摘要】 |

> **注**：标【库内·仅摘要】的，引用进正式 METHODS 前应补读全文确认其确实支持所标方法点（你强调"相关≠支持"）。我可以按你优先级逐篇补读。

### 2.3 库里没有、但方法上需要的工具/方法论文（网络来源，需另行加入参考库）
- **Snippy**（Seemann, github tseemann/snippy）——【网络/skill标准】库里没有原始引用。
- **Gubbins**：Croucher et al. 2015, *NAR* 43:e15 ——【网络/skill标准】库里没有。
- **ClonalFrameML**：Didelot & Wilson 2015, *PLoS Comput Biol* 11:e1004041 ——【网络/skill标准】库里没有。
- **FastTree 2**：Price et al. 2010, *PLoS ONE* 5:e9490 ——【网络】库里没有。
- **IQ-TREE 2**：Minh et al. 2020, *MBE* 37:1530；UFBoot2：Hoang 2018 ——【网络/skill标准】库里没有。
- **RAxML-NG**：Kozlov et al. 2019 ——【网络】库里没有。
- **Parsnp 2.0**：Kille, Nute, Huang, Kim, Phillippy, Treangen 2024, *Bioinformatics* 40(5):btae311 ——【网络】库里没有（见第七步 Parsnp 核实）。
- **Treemmer**（系统发育降采样）：Menardo et al. 2018, *BMC Bioinformatics* ——【网络/背景知识】库里没有。
- **dRep / Assembly-Dereplicator / Mash**（基因组去冗余/距离）——【网络/skill标准】库里没有。
- **skani / FastANI**（物种确认 ANI）——【skill标准】库里没有。
- **CheckM2**（污染/完整性）——【skill标准】库里没有。

---

## 第三步：这套方法在你数据集上是否合适（逐点利弊）

### (a) 样本规模与降采样 [中]

**先估 2019+ 全 VP 实际株数（低置信度估计，务必核实）：**
- **【背景知识，低置信度】** NCBI 上 VP 总基因组（assembly）数量级约 **1 万–1.5 万**（含临床+环境+水产，近年因 AHPND/食源监测激增）；其中 **2019+ 子集很可能数千（粗估 ~4,000–8,000）**。这是数量级猜测，**不可作为依据**。
- **精确查询方法（我没执行，因为本文件只做规划；你点头我可以跑）**：
  - NCBI Datasets CLI：`datasets summary genome taxon "Vibrio parahaemolyticus" --released-after 2019-01-01`（拿精确计数与元数据）；
  - BV-BRC：按 species + collection year 过滤导出；
  - PubMLST/BIGSdb VP 库：按 year 过滤，附带已分配 ST（直接拿"全 ST"分布）。
- **决策含义**：若 2019+ 实际就在 4–5k 量级 → 几乎不用降采样，全收即可；若 >8k 且高度偏向少数 ST（如 ST3/ST3-pandemic、本地优势 ST）→ 需降采样到 4–5k。

**你的降采样策略评估（"在过度代表类群内部去冗余，不砍整个 ST"）：**
- **倾向：支持你的策略 [中]**。依据：
  - **【库内】Yang 2019** 正是按 SNP 距离迭代去冗余（移除互相 <2000 SNP 者）得到非冗余集，而非删除整个谱系——同源做法。
  - **【skill标准 pathogen-typing】** 强调降采样要保留分型多样性；直接砍 ST 会丢失"全 ST 背景"这一**本树的核心目的**。
- **推荐做法（占位参数，待定）**：分层 = **ST × 国家 × 年份**；每层上限 N_max（占位，建议先试 N_max=10–20，按 2019+ 实测分布回调）；层内去冗余可选：
  - 选项①**距离去冗余**：层内按 cgMLST allele 距离或 core-SNP 距离阈值（占位，如同层内 <X 距离视为冗余）随机/代表性保留 1–k 株（Yang 2019 路线）；
  - 选项②**系统发育降采样**：先建快速树，再用 **Treemmer**【网络】按"保留 X% 多样性"裁剪；
  - 选项③**基因组去冗余**：**dRep/Assembly-Dereplicator + Mash**【网络】在 ANI/Mash 距离上去冗余（assembly 友好）。
- **必须明确标注的坑**：①降采样**必然引入抽样偏倚**，会影响群体频率类陈述——但本树只做"背景定位"不做频率推断，影响可接受，需在 Methods 写明；②**保留稀有 ST 的全部代表**（不要被 N_max 砍掉单株 ST），否则"全 ST"名不副实。

### (b) 2019+ 时间窗是否够 [中]
- **前提成立时（时间/地理由 ST50-only 树承担）**：对"把 ST50 定位进全球多样性"这个**单一目的**，2019+ 通常**够用** [中]——只要 2019+ 覆盖了全球主要 ST/群体（VppAsia/VppX/VppUS1/VppUS2 都该有代表）。
- **需要你拍板的风险点 [中]**：
  - 纯 2019+ 可能**欠采样深层/历史谱系与 backbone 锚点**（如 pandemic clone 早期代表、各群体的历史参考株）。**全球背景树的 backbone 稳定性受益于少量历史"锚点"基因组。**
  - **我主动补的建议（你没提到）**：在 2019+ 主集之外，**额外纳入一小批 curated 历史参考/代表株作为"锚点 tips"**（如 RIMD 2210633、各 Vpp 群体与主要 ST 的代表、pandemic ST3 founders），即使它们 pre-2019。这能稳住骨架、又不破坏"2019+ 为主"的设计。是否纳入、纳入哪些——**需你/Charles 拍板**。

### (c) 4–5k 规模下 reads vs assembly 的可行性 [高，含明确取舍]
这是**最关键的决策点**，且与"该套哪个 Yang 模板"绑定。

| 维度 | reads + Snippy（Yang **2022** 模板） | assembly + 比对（Yang **2019** 模板：MUMmer/Parsnp/snippy --ctgs） |
|---|---|---|
| **数据可得性** | ❌ **硬伤**：大量公共 VP 只有 assembly、**没上传 reads**；4–5k 全球株不可能都有 reads | ✅ 公共库以 assembly 为主，覆盖最全 |
| **下载/存储** | ❌ 4–5k × ~0.5–1.5 GB reads ≈ **2–7 TB** 下载+存储 | ✅ 4–5k × ~5 MB assembly ≈ **数十 GB** |
| **算力** | 每株 mapping 不贵，但 4–5k 株累积 + 全部下载，**数日级 + 大 IO** | ✅ 全基因组比对/core 提取更轻 |
| **跨 ST 准确性** | reads-mapping 在深分歧区 mapping 质量下降、core 偏小 | Yang 2019 在全球跨 ST 即用此路线 |
| **与"Snippy→RIMD"招牌一致性** | 一致 | **Snippy 也能跑 assembly：`snippy --ctgs`**【背景知识/skill】→ 可保留"Snippy→RIMD"叙事同时用 assembly |
| **与你模板叙述一致** | 表面一致（但来自单城场景） | 实质更贴近你的全球跨 ST 场景 |

- **我的倾向 [中]**：**以 assembly 为主**（覆盖最全、存算可行），用 **`snippy --ctgs` 把 assembly 比对到 RIMD**（保留 Snippy→RIMD 一致性）**或** Yang 2019 式 MUMmer/Parsnp2.0；**对少数关键株（如新测的、ST50 相关的）若有 reads 可走 reads+Snippy**——即**混合策略**。
- **需拍板**：是否接受"以 assembly 为主"偏离 2022 字面模板？（我认为这是**更诚实地贴近 Yang 团队全球场景的实际做法**，但属于科学判断，留给你。）

### (d) 5k tips 建树算力可行性 [高]
| 方法 | 5k SNP-alignment tips 可行性 | 依据 |
|---|---|---|
| **FastTree 2** | ✅ **完全可行**，分钟–小时级 | **【库内】Yang 2022 用 FastTree 建 3,642 株树**；Yang 2019 同用 FastTree2；**【skill标准】**：>1000 taxa 建议先 FastTree 探索 |
| **IQ-TREE 2 + UFBoot** | ⚠️ 可行但重：5k tips × 大 SNP 比对，**数小时–数天 + 数十 GB RAM**；可用 `-fast` 减负 | **【skill标准】** IQ-TREE2 `-fast` for >500 taxa；SNP-only 需 `+ASC` |
| **RAxML-NG** | ✅ 大树更优（transfer bootstrap 抗 rogue taxa） | **【skill标准】** "very large trees → RAxML-NG better" |

- **我的倾向 [中]**：**主树用 FastTree 2**（Yang 一致、可 scale、满足"背景定位"目的）；**若审稿/你要 support 值**，再对关键 backbone 用 **IQ-TREE2 `-fast -B 1000 -alrt 1000` 或 RAxML-NG(TBE)** 复核。
- **明确标注的坑**：
  - **FastTree 不做 `+ASC`**（ascertainment-bias 校正），SNP-only 输入下**枝长会偏**——对"背景定位拓扑"可接受，但**枝长不可作定量解读**，需在 Methods 写明限制。【skill标准】
  - 跨 ST 深分歧 + 长枝 → **注意 long-branch attraction (LBA)**【skill标准】：稀有 ST 单株长枝可能被错误吸引；缓解=加破长枝的 taxa（即保留稀有 ST 多个代表）、对结果做敏感性。

---

## 第四步：我主动补出的、你没提到但必需的步骤（含可行性评估）

> 每步标注：是否 scale 到 4–5k/全 ST/2019+ + 推荐做法 + 依据。

### S0. 数据批量获取与元数据治理 [必需，可行]
- **做法**：NCBI Datasets CLI / BV-BRC bulk / PubMLST 批量下载 assembly + 元数据（country, year, source, ST, serotype）。
- **scale**：✅ assembly 量级（数十 GB）完全可行；reads 路线则不可行（见 c）。
- **坑**：元数据缺失/不规范（年份、国家、来源），需统一清洗；**很多记录无采样年份**——会直接影响"2019+"筛选，需决定缺年份株如何处理（保留/剔除）。**需拍板**。

### S1. QC 与物种确认 [必需，可行，本树尤其重要]
- **组装 QC**：QUAST-LG **【库内 `TM8NXY46`】** + 完整性/污染 **CheckM2 或 BUSCO【库内 `VZP58Q8U`】**。阈值占位：N50、#contigs、total length（VP ~5.0–5.2 Mb）、completeness ≥X%、contamination ≤Y%。
- **物种确认（关键）**：**skani/FastANI vs RIMD ≥95% ANI** 确认确为 VP，**剔除误标注/污染/近缘种（如 V. alginolyticus）**。**【skill标准 pathogen-typing】**：ANI ≥95% = 同种；公共库混入近缘种很常见。
- **scale**：✅ skani/Mash 秒级/株，4–5k 无压力。
- **坑**：公共基因组质量参差，**跨 ST 树对混入污染/错种特别敏感（会造成假长枝/假拓扑）**——QC 不能省。

### S2. ST 分配（定义"全 ST"）[必需，可行]
- **做法**：`tseemann/mlst` vs PubMLST VP scheme（与 Yang 一致）。
- **scale**：✅ 组装上跑 mlst，4–5k 无压力。
- **坑**：会有 **novel/未分配 ST**（公共库常见）——"全 ST"是否含 untypeable/novel？分层降采样时这些怎么归类？**需拍板**。可选 cgMLST/HierCC **【库内 `SVREUT64`】** 做更细分型单位。

### S3. Reference 选择 [必需，已有依据]
- **做法**：**RIMD 2210633**（Yang 标准；ST3 pandemic 完成图）。
- **依据**：**【库内 Yang 2019 `U72LA3KE`】实测 3 个参考结论稳健** → RIMD 可用。
- **坑**：**单一线性参考的 reference-bias**【库内 `37P4YEY2`】——RIMD 缺失的区域不进 core；core 树只用 core 故可接受，但需写明"基于 RIMD-core，不代表全 pangenome"。

### S4. 比对后过滤 [必需，可行]
- **做法**：min mapping/base quality（占位 Q20，**【skill标准 variant-calling】**）、min depth（reads 路线时）、**haploid 处理**（细菌 `--ploidy 1`，**【skill标准】**——Snippy 已内置）；**剔除参考重复区**（TRF + BLASTN，**【库内 Yang 2022】**）；可选剔除已知 MGE/噬菌体/超变区。
- **scale**：✅。
- **坑**：过滤阈值影响 core 大小；需做敏感性（Yang 2022 做了阈值敏感性分析）。

### S5. core 比对构建 [必需，关键参数待定]
- **做法**：`snippy-core`（reads/ctgs 路线）或 MUMmer/Parsnp2.0 core（assembly 路线）→ concatenated core-SNP alignment。
- **关键参数：core 阈值** —— **占位，需拍板**：
  - Yang 2022 = **>99.5%**（单城低分歧）；Yang 2019 = **100%**（更严，但 core 更小）。
  - **跨 ST 4–5k 时 100% core 会非常小 → SNP 太少、分辨率不足**（**【库内 Yang 2019】**已证 core 随株数/广度缩小）。
  - **我的倾向 [中]**：用 **soft-core（如 ≥95–99% presence）** 换取足够 SNP 数；具体阈值待 2019+ 实测 core 曲线后定。
- **坑**：core 阈值是**本树最敏感的单一参数**——直接决定可用 SNP 数与树的分辨率。建议产出"core 大小 vs presence 阈值"曲线辅助决策。

### S6. 重组处理（见第七步核实）[本树：不做全树 Gubbins]
- 见第七步结论。本树不对全树跑 Gubbins/ClonalFrameML。

### S7. 建树 [见 (d)]
- FastTree 2 主树（+ 可选 IQ-TREE2/RAxML-NG 复核）。

### S8. 定根 (rooting) [必需，你没提，需拍板]
- **做法选项**：①**外群定根**（近缘种如 *V. alginolyticus* 或 VP 内某分化最深谱系）——拓扑更可信；②midpoint rooting——简单但跨 ST 深分歧下可能误根。
- **倾向 [低]**：跨 ST 物种树建议**外群定根**；外群选择需查文献（**需补充检索**）。**需拍板**。

### S9. 可视化与标注 [必需，可行]
- **做法**：iTOL（**【库内 Yang 2019/2022】用 iTOL**）/ ggtree / Microreact；按 **ST、国家、年份、tdh/trh、ST50-clade** 上色注释，重点高亮 **ST50 在全球树中的位置**（呼应本树目的）。
- **scale**：✅ 5k tips iTOL/Microreact 可渲染。

### S10. 可重复性 [必需]
- 固定**工具版本、随机种子、PubMLST/schema 抓取日期、reference 版本**。**【skill标准】** 反复强调 schema/版本钉死。

---

## 第五步：未决决策点汇总（选项 + 利弊 + 我的倾向 + 谁拍板）

| # | 决策点 | 选项 | 我的倾向 | 谁拍板 |
|---|---|---|---|---|
| D1 | **reads vs assembly** | A) reads+Snippy(2022模板) B) assembly+`snippy --ctgs`/MUMmer/Parsnp2.0(2019模板) C) 混合 | **B 或 C**（A 因公共株无 reads + 存储 2–7 TB 基本不可行） | **你/Charles** |
| D2 | **降采样策略** | 层内距离去冗余 / Treemmer / dRep+Mash / 不降采样 | 先实测 2019+ 株数与 ST 分布，>8k 偏态才降；按 **ST×国家×年份**分层、层内去冗余、**保稀有 ST 全代表** | **你**（先看实测） |
| D3 | **core presence 阈值** | 100% / >99.5% / soft-core ≥95–99% | **soft-core**（换 SNP 数），具体待 core 曲线 | **你**（看曲线） |
| D4 | **建树工具/support** | FastTree(无 support) / +IQ-TREE2 `-fast`+UFBoot / +RAxML-NG(TBE) | FastTree 主树；要 support 再复核 backbone | **你**（看是否需 support） |
| D5 | **是否纳入 pre-2019 锚点株** | 纯 2019+ / +少量历史锚点 | **+少量 curated 锚点**稳骨架 | **你/Charles** |
| D6 | **定根方式** | 外群 / midpoint | 外群（需选外群） | **你/Charles** |
| D7 | **novel/无年份/untypeable 株处理** | 保留 / 剔除 / 单列 | 需先看占比 | **你** |
| D8 | **库内仅摘要文献是否引用** | 补读全文确认 / 不引 | 引用前补读（你强调相关≠支持） | **你定优先级** |

---

## 第六步：算力/存储/scale 风险清单（集中标注）

- **存储**：reads 路线 2–7 TB（**可能不可行**）；assembly 路线数十 GB（可行）。**[高]**
- **下载耗时**：4–5k SRA reads 下载数日；assembly 数小时。**[高]**
- **core 缩水**：株越多/跨 ST 越广，core 越小（**【库内 Yang 2019】实证**）——4–5k 全 ST 下 core 可能显著小于 2022 单城。**[高]**
- **IQ-TREE+UFBoot 内存/时间**：5k tips 可能数十 GB RAM、数天——若选此路线需先在子集压测。**[中]**
- **FastTree 枝长无 ASC 校正**：枝长不可定量解读。**[高]**
- **LBA**：稀有 ST 长枝错置风险——保多代表 + 敏感性。**[中]**
- **公共数据质量/污染/错种**：跨 ST 树高度敏感，QC(ANI) 不可省。**[高]**
- **元数据缺失**（年份/国家）：直接影响 2019+ 筛选与降采样分层。**[中]**

---

## 第七步：核实"不跑 Gubbins / 不用 Parsnp"两点

### 7.1 "4–5k 全 ST 不适合跑 Gubbins" —— **确认成立（理由比你给的更完整）[高]**
你的理由：①跨 ST 深分歧下 clonal frame 假设不成立；②5k 算力不可行。**两点都成立**，并有三方印证：

1. **方法学（skill标准）**：**【skill标准 phylodynamics】** Gubbins 是**滑窗检测异常 SNP 密度、基于单一 clonal frame**的工具，明确"**Gubbins cannot detect ancient recombination; mis-masks mutation hotspots**"。跨全 ST 的深层/古老重组正是它**检测不了且会误掩**的情形 → 假设不成立。✔ 支持你的①。
2. **Yang 团队自己的做法（库内）**：**【库内 Yang 2022】Gubbins v2.3.4 只用在 FDOS-outbreak(克隆型)株内**，对 3,642 株**全树用 FastTree、不跑 Gubbins**；**【库内 Yang 2019】**全球跨 ST 树也**未用 Gubbins**。✔ 直接先例。
3. **目的论**：**【skill标准】** Gubbins/重组掩蔽的主要价值在**分子钟/dating 前**降低钟速虚高（2–5×）。**你这棵树不做 dating（时间论点在 ST50-only 树）→ 全树掩蔽既不适用也无必要。** ✔ 支持。
4. **算力**：**【背景知识】** Gubbins 需迭代建树+重组检测，对 5k 深分歧基因组**不可行且会误收敛**。✔ 支持你的②。

> **但要写进 Methods 的限制 [高]**：不掩蔽重组 → **本树枝长被重组抬高**；对"背景定位拓扑"可接受，但**枝长/距离不可定量解读**，需明确声明。
> **延伸提醒（关于另一棵树）[高]**：**ST50-only 树若要承担时间论点（dating），那棵树内是 clonal frame 成立的场景，反而 _应该_ 先做重组掩蔽**（ST50 内用 **Gubbins 或 ClonalFrameML** → 再建树 → 再 TreeTime/BEAST），否则钟速虚高 2–5×（**【skill标准 phylodynamics】核心警示**）。这正好是两棵树的方法学分工：全球树不掩蔽（仅定位）、ST50 树掩蔽（做时间）。

### 7.2 "不用 Parsnp（上千就不 scale）" —— **结论部分修正：前提过时，但仍有不选它的正当理由 [高]**
- **你的"上千不 scale"前提已过时**：**【网络】Parsnp 2.0**（Kille, Nute, Huang, Kim, Phillippy, Treangen 2024, *Bioinformatics* btae311）引入 **partitioning**，**专门 scale 到数千个细菌/病毒基因组**，内存降 >4×、运行时降 >2×。所以"Parsnp 上千就不 scale"**不再成立**——我不照此理由确认。
- **真正可作为"不优先用 Parsnp"的理由（供你判断，非定论）**：
  1. **与 Yang 模板/可比性**：Yang 全球树用 **MUMmer→RIMD**（2019）、单城用 **Snippy→RIMD**（2022）；走 RIMD-reference 路线与你"跟 Yang"的叙事更一致。**[中]**
  2. **跨 ST 深分歧下 core 缩水**：Parsnp 基于参考锚定的 LCB core，**genome 越分歧 core 越小**——这是**所有 core 方法的共性问题**（**【库内 Yang 2019】实证**），非 Parsnp 独有，故**不能拿来单独否定 Parsnp**。
  3. **Parsnp 反而是 assembly 路线的合理候选**：若选 D1=assembly 路线，**Parsnp 2.0 完全是一个可行的 core-genome 比对工具**（甚至比手搭 MUMmer 流程省事）。
- **修正后的我的倾向 [中]**：不是"Parsnp 不能用"，而是"**RIMD-reference 路线（Snippy --ctgs / MUMmer）与 Yang 可比性更好**；Parsnp 2.0 作为 assembly 路线的备选保留"。**最终选择留给你/Charles。**

---

## 附：参考文献清单（按来源分列）

### A. 库内（你的 Zotero，可直接引用；标*者已读全文核实）
- *Yang et al. 2022, *Nat Microbiol* 7:1221 — `64IARYIZ`（模板）
- *Yang et al. 2019, *ISME J* 13:2578 — `U72LA3KE`（全球跨 ST 交叉参照）
- Gonzalez-Escalona et al. 2017, *J Clin Microbiol* — `SVREUT64`（VP cgMLST）
- Tsang et al. 2017 — `9DQP3AJM`（MLST≠系统发育）
- Martinez-Urtaza 2026 — `L85VRICU`（克隆↔重组连续谱）
- Urhan & Abeel 2021 — `37P4YEY2`（reference-bias）
- Jesser et al. 2019 — `VLV89EP8`（VP MLST+WGS）
- Campbell et al. 2024 — `HXLPQEHE`（VP ST3 谱系）
- Yang et al. 2025 — `U5WDYDMI`（最新大规模 VP，建议补读 Methods）
- Mikheenko et al. 2018 QUAST-LG — `TM8NXY46`；Manni et al. 2021 BUSCO — `VZP58Q8U`；Wick et al. 2023 — `A25DFNYU`

### B. 网络/skill 标准（不在你库，引用前需加入参考库）
- Snippy（Seemann）；Croucher 2015 Gubbins(*NAR* 43:e15)；Didelot & Wilson 2015 ClonalFrameML；Price 2010 FastTree2；Minh 2020 IQ-TREE2 / Hoang 2018 UFBoot2；Kozlov 2019 RAxML-NG；**Kille et al. 2024 Parsnp 2.0 (*Bioinformatics* 40:btae311)**；Menardo 2018 Treemmer；Ondov 2016 Mash；skani/FastANI；CheckM2。

### C. 网络检索原始链接
- Parsnp 2.0：https://academic.oup.com/bioinformatics/article/40/5/btae311/7667868 ; https://pmc.ncbi.nlm.nih.gov/articles/PMC11128092/
- VP 基因组计数（未得精确数）：PubMLST https://pubmlst.org/organisms/vibrio-parahaemolyticus ; Gonzalez-Escalona 2017 https://pmc.ncbi.nlm.nih.gov/articles/PMC5442524/

---

## 待你决策的优先三件事（建议顺序）
1. **批准我去实测 2019+ VP 株数与 ST/国家/年份分布**（NCBI Datasets / BV-BRC / PubMLST）——这决定 D2/D3 全部下游。
2. **拍板 D1（reads vs assembly）**——决定整条 SNP 流程与存算预算。
3. **指定要我补读全文的库内文献优先级**（把【库内·仅摘要】升级为已核实，再进正式 Methods）。
