---
sr-due: 2026-04-15
sr-interval: 1
sr-ease: 227
---
# 一、英语原文
# LLM Wiki

A pattern for building personal knowledge bases using LLMs.

This is an idea file, it is designed to be copy pasted to your own LLM Agent (e.g. OpenAI Codex, Claude Code, OpenCode / Pi, or etc.). Its goal is to communicate the high level idea, but your agent will build out the specifics in collaboration with you.

## The core idea

Most people's experience with LLMs and documents looks like RAG: you upload a collection of files, the LLM retrieves relevant chunks at query time, and generates an answer. This works, but the LLM is rediscovering knowledge from scratch on every question. There's no accumulation. Ask a subtle question that requires synthesizing five documents, and the LLM has to find and piece together the relevant fragments every time. Nothing is built up. NotebookLM, ChatGPT file uploads, and most RAG systems work this way.

The idea here is different. Instead of just retrieving from raw documents at query time, the LLM **incrementally builds and maintains a persistent wiki** — a structured, interlinked collection of markdown files that sits between you and the raw sources. When you add a new source, the LLM doesn't just index it for later retrieval. It reads it, extracts the key information, and integrates it into the existing wiki — updating entity pages, revising topic summaries, noting where new data contradicts old claims, strengthening or challenging the evolving synthesis. The knowledge is compiled once and then *kept current*, not re-derived on every query.

This is the key difference: **the wiki is a persistent, compounding artifact.** The cross-references are already there. The contradictions have already been flagged. The synthesis already reflects everything you've read. The wiki keeps getting richer with every source you add and every question you ask.

You never (or rarely) write the wiki yourself — the LLM writes and maintains all of it. You're in charge of sourcing, exploration, and asking the right questions. The LLM does all the grunt work — the summarizing, cross-referencing, filing, and bookkeeping that makes a knowledge base actually useful over time. In practice, I have the LLM agent open on one side and Obsidian open on the other. The LLM makes edits based on our conversation, and I browse the results in real time — following links, checking the graph view, reading the updated pages. Obsidian is the IDE; the LLM is the programmer; the wiki is the codebase.

This can apply to a lot of different contexts. A few examples:

- **Personal**: tracking your own goals, health, psychology, self-improvement — filing journal entries, articles, podcast notes, and building up a structured picture of yourself over time.
- **Research**: going deep on a topic over weeks or months — reading papers, articles, reports, and incrementally building a comprehensive wiki with an evolving thesis.
- **Reading a book**: filing each chapter as you go, building out pages for characters, themes, plot threads, and how they connect. By the end you have a rich companion wiki. Think of fan wikis like [Tolkien Gateway](https://tolkiengateway.net/wiki/Main_Page) — thousands of interlinked pages covering characters, places, events, languages, built by a community of volunteers over years. You could build something like that personally as you read, with the LLM doing all the cross-referencing and maintenance.
- **Business/team**: an internal wiki maintained by LLMs, fed by Slack threads, meeting transcripts, project documents, customer calls. Possibly with humans in the loop reviewing updates. The wiki stays current because the LLM does the maintenance that no one on the team wants to do.
- **Competitive analysis, due diligence, trip planning, course notes, hobby deep-dives** — anything where you're accumulating knowledge over time and want it organized rather than scattered.

## Architecture

There are three layers:

**Raw sources** — your curated collection of source documents. Articles, papers, images, data files. These are immutable — the LLM reads from them but never modifies them. This is your source of truth.

**The wiki** — a directory of LLM-generated markdown files. Summaries, entity pages, concept pages, comparisons, an overview, a synthesis. The LLM owns this layer entirely. It creates pages, updates them when new sources arrive, maintains cross-references, and keeps everything consistent. You read it; the LLM writes it.

**The schema** — a document (e.g. CLAUDE.md for Claude Code or AGENTS.md for Codex) that tells the LLM how the wiki is structured, what the conventions are, and what workflows to follow when ingesting sources, answering questions, or maintaining the wiki. This is the key configuration file — it's what makes the LLM a disciplined wiki maintainer rather than a generic chatbot. You and the LLM co-evolve this over time as you figure out what works for your domain.

## Operations

**Ingest.** You drop a new source into the raw collection and tell the LLM to process it. An example flow: the LLM reads the source, discusses key takeaways with you, writes a summary page in the wiki, updates the index, updates relevant entity and concept pages across the wiki, and appends an entry to the log. A single source might touch 10-15 wiki pages. Personally I prefer to ingest sources one at a time and stay involved — I read the summaries, check the updates, and guide the LLM on what to emphasize. But you could also batch-ingest many sources at once with less supervision. It's up to you to develop the workflow that fits your style and document it in the schema for future sessions.

**Query.** You ask questions against the wiki. The LLM searches for relevant pages, reads them, and synthesizes an answer with citations. Answers can take different forms depending on the question — a markdown page, a comparison table, a slide deck (Marp), a chart (matplotlib), a canvas. The important insight: **good answers can be filed back into the wiki as new pages.** A comparison you asked for, an analysis, a connection you discovered — these are valuable and shouldn't disappear into chat history. This way your explorations compound in the knowledge base just like ingested sources do.

**Lint.** Periodically, ask the LLM to health-check the wiki. Look for: contradictions between pages, stale claims that newer sources have superseded, orphan pages with no inbound links, important concepts mentioned but lacking their own page, missing cross-references, data gaps that could be filled with a web search. The LLM is good at suggesting new questions to investigate and new sources to look for. This keeps the wiki healthy as it grows.

## Indexing and logging

Two special files help the LLM (and you) navigate the wiki as it grows. They serve different purposes:

**index.md** is content-oriented. It's a catalog of everything in the wiki — each page listed with a link, a one-line summary, and optionally metadata like date or source count. Organized by category (entities, concepts, sources, etc.). The LLM updates it on every ingest. When answering a query, the LLM reads the index first to find relevant pages, then drills into them. This works surprisingly well at moderate scale (~100 sources, ~hundreds of pages) and avoids the need for embedding-based RAG infrastructure.

**log.md** is chronological. It's an append-only record of what happened and when — ingests, queries, lint passes. A useful tip: if each entry starts with a consistent prefix (e.g. `## [2026-04-02] ingest | Article Title`), the log becomes parseable with simple unix tools — `grep "^## \[" log.md | tail -5` gives you the last 5 entries. The log gives you a timeline of the wiki's evolution and helps the LLM understand what's been done recently.

## Optional: CLI tools

At some point you may want to build small tools that help the LLM operate on the wiki more efficiently. A search engine over the wiki pages is the most obvious one — at small scale the index file is enough, but as the wiki grows you want proper search. [qmd](https://github.com/tobi/qmd) is a good option: it's a local search engine for markdown files with hybrid BM25/vector search and LLM re-ranking, all on-device. It has both a CLI (so the LLM can shell out to it) and an MCP server (so the LLM can use it as a native tool). You could also build something simpler yourself — the LLM can help you vibe-code a naive search script as the need arises.

## Tips and tricks

- **Obsidian Web Clipper** is a browser extension that converts web articles to markdown. Very useful for quickly getting sources into your raw collection.
- **Download images locally.** In Obsidian Settings → Files and links, set "Attachment folder path" to a fixed directory (e.g. `raw/assets/`). Then in Settings → Hotkeys, search for "Download" to find "Download attachments for current file" and bind it to a hotkey (e.g. Ctrl+Shift+D). After clipping an article, hit the hotkey and all images get downloaded to local disk. This is optional but useful — it lets the LLM view and reference images directly instead of relying on URLs that may break. Note that LLMs can't natively read markdown with inline images in one pass — the workaround is to have the LLM read the text first, then view some or all of the referenced images separately to gain additional context. It's a bit clunky but works well enough.
- **Obsidian's graph view** is the best way to see the shape of your wiki — what's connected to what, which pages are hubs, which are orphans.
- **Marp** is a markdown-based slide deck format. Obsidian has a plugin for it. Useful for generating presentations directly from wiki content.
- **Dataview** is an Obsidian plugin that runs queries over page frontmatter. If your LLM adds YAML frontmatter to wiki pages (tags, dates, source counts), Dataview can generate dynamic tables and lists.
- The wiki is just a git repo of markdown files. You get version history, branching, and collaboration for free.

## Why this works

The tedious part of maintaining a knowledge base is not the reading or the thinking — it's the bookkeeping. Updating cross-references, keeping summaries current, noting when new data contradicts old claims, maintaining consistency across dozens of pages. Humans abandon wikis because the maintenance burden grows faster than the value. LLMs don't get bored, don't forget to update a cross-reference, and can touch 15 files in one pass. The wiki stays maintained because the cost of maintenance is near zero.

The human's job is to curate sources, direct the analysis, ask good questions, and think about what it all means. The LLM's job is everything else.

The idea is related in spirit to Vannevar Bush's Memex (1945) — a personal, curated knowledge store with associative trails between documents. Bush's vision was closer to this than to what the web became: private, actively curated, with the connections between documents as valuable as the documents themselves. The part he couldn't solve was who does the maintenance. The LLM handles that.


## Note

This document is intentionally abstract. It describes the idea, not a specific implementation. The exact directory structure, the schema conventions, the page formats, the tooling — all of that will depend on your domain, your preferences, and your LLM of choice. Everything mentioned above is optional and modular — pick what's useful, ignore what isn't. For example: your sources might be text-only, so you don't need image handling at all. Your wiki might be small enough that the index file is all you need, no search engine required. You might not care about slide decks and just want markdown pages. You might want a completely different set of output formats. The right way to use this is to share it with your LLM agent and work together to instantiate a version that fits your needs. The document's only job is to communicate the pattern. Your LLM can figure out the rest.

# 二、中文翻译
# LLM Wiki

一种使用大语言模型构建个人知识库的模式。

这是一个想法文件，设计为可以复制粘贴到你自己的LLM代理中（例如OpenAI Codex、Claude Code、OpenCode / Pi等）。它的目标是传达高层次的想法，但你的代理会与你合作构建具体细节。

## 核心理念

大多数人与LLM和文档的体验看起来像RAG（检索增强生成）：你上传一组文件，LLM在查询时检索相关片段，然后生成答案。这种方法有效，但LLM每次提问都需要从头重新发现知识。没有积累。当提出一个需要综合五份文档的微妙问题时，LLM必须每次都找到并拼接相关片段。没有任何东西被构建起来。NotebookLM、ChatGPT文件上传和大多数RAG系统都是这样工作的。

这里的想法不同。不仅仅是在查询时从原始文档中检索，LLM**增量构建并维护一个持久的wiki**—一个结构化的、相互链接的markdown文件集合，它位于你和原始源之间。当你添加新源时，LLM不仅仅是为了后续检索而索引它。它会阅读源文件，提取关键信息，并将其整合到现有的wiki中—更新实体页面，修订主题摘要，标记新数据与旧声明相矛盾的地方，加强或挑战不断发展的综合。知识只被编译一次，然后*保持最新*，而不是每次查询都重新推导。

这是关键区别：**wiki是一个持久的、累积的产物。**交叉引用已经存在。矛盾已经被标记。综合已经反映了你阅读的所有内容。每当你添加一个源文件，每当你提出一个问题，wiki都会变得更加丰富。

你（或很少）自己编写wiki—LLM编写并维护所有内容。你负责来源、探索和提出正确的问题。LLM负责所有繁琐的工作—总结、交叉引用、归档和记账，这些工作使知识库随时间推移变得真正有用。在实践中，我在一侧打开LLM代理，在另一侧打开Obsidian。LLM根据我们的对话进行编辑，我实时浏览结果—跟随链接，检查图谱视图，阅读更新的页面。Obsidian是IDE；LLM是程序员；wiki是代码库。

这可以应用于许多不同的上下文。几个例子：

- **个人**：跟踪你自己的目标、健康、心理、自我改进—归档日记条目、文章、播客笔记，并随时间构建一个关于自己的结构化图景。
- **研究**：在几周或几个月内深入研究一个主题—阅读论文、文章、报告，并逐步构建一个包含不断发展的论点的综合wiki。
- **阅读书籍**：边读边将每一章归档，为角色、主题、情节线索及其联系建立页面。到结束时，你将拥有一个丰富的配套wiki。想想像[托尔金门户](https://tolkiengateway.net/wiki/Main_Page)这样的粉丝wiki—由志愿者社区多年来构建的数千个相互链接的页面，涵盖角色、地点、事件、语言。你可以像这样在阅读时个人构建类似的东西，LLM负责所有的交叉引用和维护。
- **商业/团队**：由LLM维护的内部wiki，由Slack线程、会议记录、项目文档、客户通话提供支持。可能有人类参与循环审查更新。wiki保持最新，因为LLM做了团队中没有人愿意做的维护工作。
- **竞争分析、尽职调查、旅行计划、课程笔记、爱好深度探索**—任何你随时间积累知识并希望它组织起来而不是散落的情况。

## 架构

有三层：

**原始源**—你精心挑选的源文档集合。文章、论文、图像、数据文件。这些是不可变的—LLM从中读取但不修改它们。这是你的事实来源。

**Wiki**—一个由LLM生成的markdown文件目录。摘要、实体页面、概念页面、比较、概述、综合。LLM完全拥有这一层。它创建页面，当新源到达时更新它们，维护交叉引用，并保持一切一致。你阅读它；LLM编写它。

**模式**—一个文档（例如Claude Code的CLAUDE.md或Codex的AGENTS.md），它告诉LLM wiki是如何构建的，约定是什么，以及在摄取源、回答问题或维护wiki时应遵循什么工作流程。这是关键的配置文件—它使LLM成为一个有纪律的wiki维护者，而不是通用的聊天机器人。你和LLM随时间共同发展它，因为你为你的领域找出什么有效。

## 操作

**摄取**。你将一个新的源文件放入原始集合中，并告诉LLM处理它。一个示例流程：LLM读取源文件，与你讨论关键要点，在wiki中编写摘要页面，更新索引，更新wiki中相关的实体和概念页面，并在日志中添加一个条目。单个源文件可能会触及10-15个wiki页面。我个人更喜欢一次摄取一个源文件并保持参与—我阅读摘要，检查更新，并指导LLM强调什么。但你也可以一次批量摄取多个源文件，监督较少。这取决于你开发适合你风格的工作流程，并将其记录在模式中，以便将来使用。

**查询**。你对wiki提出问题。LLM搜索相关页面，阅读它们，并引用合成答案。答案可以采取不同的形式，取决于问题—一个markdown页面，一个比较表，一个幻灯片 deck（Marp），一个图表（matplotlib），一个画布。重要的见解：**好的答案可以作为新页面重新归档到wiki中。**你要求的比较、分析、你发现的联系—这些都是有价值的，不应该消失在聊天历史中。这样，你的探索就像摄取的源文件一样在知识库中积累。

**检查**。定期，要求LLM对wiki进行健康检查。查找：页面之间的矛盾、被更新的源文件所取代的过时声明、没有入站链接的孤立页面、被提及但缺乏自己页面的重要概念、缺失的交叉引用、可以通过网络搜索填补的数据空白。LLM擅长建议新的问题调查和新的源文件查找。这随着wiki的增长保持其健康。

## 索引和日志

两个特殊文件帮助LLM（和你）随着wiki的增长进行导航。它们服务于不同的目的：

**index.md**是内容导向的。它是wiki中所有内容的目录—每个页面都列有链接、一行摘要和可选的元数据（如日期或源文件计数）。按类别组织（实体、概念、源文件等）。LLM在每次摄取时更新它。在回答查询时，LLM首先读取索引以查找相关页面，然后深入研究它们。在中等规模（约100个源文件，数百个页面）时，这出人意料地有效，避免了基于嵌入的RAG基础设施的需求。

**log.md**是按时间顺序的。它是一个只追加的记录，记录了发生的事情和时间—摄取、查询、检查通过。一个有用的技巧：如果每个条目以一致的prefix开头（例如`## [2026-04-02] 摄取 | 文章标题`），日志变得可以用简单的unix工具解析—`grep "^## \[" log.md | tail -5`给你最后5个条目。日志给你wiki演变的的时间线，并帮助LLM理解最近完成了什么。

## 可选：CLI工具

在某个时候，你可能想要构建一些小工具，帮助LLM更有效地操作wiki。在wiki页面上的搜索引擎是最明显的选择—在小规模时，索引文件就足够了，但随着wiki的增长，你需要适当的搜索。[qmd](https://github.com/tobi/qmd)是一个好选择：它是markdown文件的本地搜索引擎，具有混合BM25/向量搜索和LLM重新排序功能，全部在设备上完成。它既有CLI（因此LLM可以shell out到它）也有MCP服务器（因此LLM可以将其用作原生工具）。你也可以构建更简单的东西—LLM可以帮助你根据需要快速编写一个朴素的搜索脚本。

## 技巧和窍门

- **Obsidian网页剪辑器**是一个浏览器扩展，将网络文章转换为markdown。对于快速将源文件放入你的原始集合非常有用。
- **本地下载图像**。在Obsidian设置→文件和链接中，将"附件文件夹路径"设置为固定目录（例如`raw/assets/`）。然后在设置→快捷键中，搜索"下载"以找到"为当前文件下载附件"并将其绑定到快捷键（例如Ctrl+Shift+D）。在剪辑文章后，点击快捷键，所有图像都会下载到本地磁盘。这是可选的但很有用—它让LLM可以直接查看和引用图像，而不是可能失效的URL。请注意，LLM不能一次性原生读取带有内联图像的markdown—解决方法是让LLM先读取文本，然后单独查看部分或所有引用的图像以获得额外上下文。这有点笨拙，但效果足够好。
- **Obsidian的图谱视图**是查看wiki形状的最佳方式—什么连接到什么，哪些页面是中心，哪些是孤立的。
- **Marp**是基于markdown的幻灯片格式。Obsidian有一个插件。用于直接从wiki内容生成演示文稿。
- **Dataview**是Obsidian插件，在页面前置元数据上运行查询。如果你的LLM向wiki页面添加YAML前置元数据（标签、日期、源文件计数），Dataview可以生成动态表格和列表。
- wiki只是markdown文件的git仓库。你免费获得版本历史、分支和协作。

## 为什么这有效

维护知识库的乏味部分不是阅读或思考—而是记账。更新交叉引用，保持摘要最新，标记新数据与旧声明相矛盾的地方，在数十个页面之间保持一致性。人类放弃wiki是因为维护负担的增长速度快于价值的增长。LLM不会感到厌倦，不会忘记更新交叉引用，可以在一次操作中触及15个文件。wiki保持维护，因为维护成本接近于零。

人类的工作是策划源文件、指导分析、提出好问题，并思考所有这些意味着什么。LLM的工作是其他一切。

这个想法在精神上与Vannevar Bush的Memex（1945）相关—一个个人的、精心策划的知识存储，具有文档之间的关联路径。Bush的愿景比网络成为的样子更接近这个：私人的、积极策划的，文档之间的连接与文档本身一样有价值。他无法解决的部分是谁来做维护。LLM处理了这一点。

## 注意

这份文件是有意抽象的。它描述的是想法，而不是特定的实现。确切的目录结构、模式约定、页面格式、工具—所有这些都取决于你的领域、你的偏好和你的LLM选择。上面提到的所有内容都是可选和模块化的—选择有用的，忽略无用的。例如：你的源文件可能只是文本，所以你根本不需要图像处理。你的wiki可能足够小，索引文件就是你需要的全部，不需要搜索引擎。你可能不关心幻灯片，只想要markdown页面。你可能想要一套完全不同的输出格式。使用它的正确方式是与你的LLM代理分享它，并一起合作实现一个适合你需求的版本。文件的唯一工作是传达这个模式。你的LLM可以找出其余部分。


# 三、提炼内容：
# LLM Wiki 方法论核心要点提炼

什么是 LLM Wiki的核心理念？
一种基于注意力机制的神经网络结构

## 核心理念

- **增量构建持久Wiki**：不同于传统的RAG（检索增强生成）每次查询都重新发现知识，LLM Wiki是一个结构化、相互链接的markdown文件集合，在原始源和用户之间建立持久层
- **知识积累而非重复推导**：知识只被编译一次，然后保持最新，而不是每次查询都重新推导
- **LLM负责维护**：LLM负责所有繁琐工作（总结、交叉引用、归档、记账），用户负责来源、探索和提问

## 三层架构

1. **原始源层**：不可变的源文档集合（文章、论文、图像等），作为事实来源
2. **Wiki层**：LLM生成的markdown文件目录（摘要、实体页面、概念页面等），由LLM完全维护
3. **模式层**：配置文件，定义wiki构建约定和工作流程，使LLM成为有纪律的wiki维护者

## 主要操作

- **摄取**：将新源文件加入集合，LLM阅读、讨论、编写摘要、更新索引和相关页面
- **查询**：LLM搜索相关页面，合成答案，可将答案作为新页面归档到wiki中
- **检查**：定期进行健康检查，查找矛盾、过时声明、孤立页面等

## 辅助文件

- **index.md**：内容导向的目录，按类别组织所有wiki页面
- **log.md**：时间顺序记录，记录摄取、查询、检查等活动

## 实用工具与技巧

- **Obsidian网页剪辑器**：将网络文章转换为markdown
- **本地图像下载**：确保LLM可直接查看和引用图像
- **Obsidian图谱视图**：查看wiki结构和连接关系
- **Marp**：基于markdown的幻灯片格式，用于生成演示文稿
- **Dataview**：查询页面元数据，生成动态表格和列表

## 核心优势

- **维护成本低**：LLM不会感到厌倦，不会忘记更新交叉引用，可同时处理多个文件
- **知识保持最新**：随着新源加入，wiki自动更新，保持一致性
- **人类专注高价值工作**：用户只需负责策划源文件、指导分析和提出好问题

## 适用场景

- 个人知识管理（目标、健康、心理、自我改进）
- 深入研究（论文、文章、报告的综合）
- 阅读书籍（角色、主题、情节线索的归档）
- 商业/团队知识库（Slack线程、会议记录、项目文档）
- 竞争分析、尽职调查、旅行计划、课程笔记等

这种方法论通过将LLM作为知识库的维护者，解决了传统知识管理中维护负担过大的问题，使知识能够真正积累和保持最新。

#review 
# LLM Wiki 方法论复习卡片

#flashcard Karpathy的LLM Wiki方法与传统RAG方法的主要区别是什么？
==传统RAG每次查询都重新发现知识，没有积累；而LLM Wiki构建持久的、累积的wiki结构，知识只被编译一次并保持最新，交叉引用已存在，矛盾已被标记。==
**间隔**: 1天
<!--SR:!2026-04-15,1,217-->

#flashcard LLM Wiki架构包含哪三个层次？
==1) 原始源(不可变的源文档) 2) Wiki(LLM生成的markdown文件集合) 3) 模式(配置文件，定义wiki构建约定和工作流程) ==
**间隔**: 3天
<!--SR:!2026-04-15,1,217-->

#flashcard 在LLM Wiki中，"摄取"操作的具体流程是什么？
==LLM读取源文件，与用户讨论关键要点，在wiki中编写摘要页面，更新索引，更新相关实体和概念页面，并在日志中添加条目。单个源可能触及10-15个wiki页面。==
**间隔**: 7天
<!--SR:!2026-04-15,1,217-->

#flashcard index.md文件在LLM Wiki中扮演什么角色？
==index.md是内容导向的目录，列出wiki中所有页面，每个页面包含链接、一行摘要和可选元数据，按类别组织。LLM在每次摄取时更新它，回答查询时先读取索引以查找相关页面。==
**间隔**: 5天
<!--SR:!2026-04-17,3,254-->

#flashcard log.md文件的作用是什么？有什么实用技巧？
==log.md是按时间顺序的只追加记录，记录摄取、查询等活动。技巧：每个条目以一致前缀开头(如`## [日期] 摄取 | 标题`)，可用`grep "^## \[" log.md | tail -5`快速获取最近5个条目。==
**间隔**: 4天
<!--SR:!2026-04-17,3,254-->

#flashcard 为什么说LLM Wiki能有效解决传统知识库维护问题？
==传统知识库维护负担增长快于价值增长，人类会因厌倦而放弃。LLM不会厌倦，不会忘记更新交叉引用，可在一次操作中触及多个文件，使维护成本接近于零。==
**间隔**: 10天
<!--SR:!2026-04-17,3,254-->

#flashcard Karpathy推荐的用于LLM Wiki的CLI工具是什么？它有什么特点？
==qmd，一个本地markdown文件搜索引擎，具有混合BM25/向量搜索和LLM重新排序功能，全部在设备上完成。既有CLI也有MCP服务器，适合LLM使用。==
**间隔**: 6天
<!--SR:!2026-04-17,3,254-->

#flashcard 在Obsidian中如何有效处理LLM Wiki中的图像？ :: 1) 设置固定附件文件夹路径：`raw/assets/` \n 2) 绑定下载附件快捷键 \n 3) 剪辑后点击快捷键下载图像到本地
<!--SR:!2026-04-17,3,254-->
**间隔**: 8天

?hello
---yes
