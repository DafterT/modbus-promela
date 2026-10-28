% itmo-report.cls — отчёты по лабораторным (ИТМО), классический LaTeX-стиль.
% Компиляция: XeLaTeX (см. latexmkrc).
%
% Опции класса: всё, что понимает article (11pt, 12pt, twoside …), плюс
%   nosignatures — убрать линии для подписей с титульного листа.
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{itmo-report}[2026/10/03 ITMO lab report]

\newif\if@signatures \@signaturestrue
\DeclareOption{nosignatures}{\@signaturesfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[a4paper,12pt]{article}

% ---------------------------------------------------------------- Шрифты и язык
\RequirePackage{amsmath,amssymb,amsthm}
\RequirePackage{fontspec}
% Computer Modern с кириллицей (пакет cm-unicode из TeX Live). Без него — запасной вариант.
\IfFontExistsTF{CMU Serif}{%
  \setmainfont{CMU Serif}
  \setsansfont{CMU Sans Serif}
  \setmonofont{CMU Typewriter Text}
}{%
  \ClassWarningNoLine{itmo-report}{CMU fonts not found, falling back to DejaVu.
    Install them: tlmgr install cm-unicode}
  \setmainfont{DejaVu Serif}
  \setsansfont{DejaVu Sans}
  \setmonofont{DejaVu Sans Mono}
}
\RequirePackage{polyglossia}
\setmainlanguage{russian}
\setotherlanguage{english}
\RequirePackage{microtype}

% ---------------------------------------------------------------- Страница
\RequirePackage[top=25mm,bottom=25mm,left=25mm,right=20mm]{geometry}
\RequirePackage{indentfirst}
\setlength{\parindent}{1.25em}

% ---------------------------------------------------------------- Списки
\RequirePackage{enumitem}
\setlist{itemsep=0.2em, topsep=0.4em}
\setlist[itemize]{label=---}

% ---------------------------------------------------------------- Рисунки, таблицы, листинги
\RequirePackage{graphicx}
\graphicspath{{figures/}}
\RequirePackage{float}
\RequirePackage{booktabs,tabularx,multirow,array}
\RequirePackage[dvipsnames,table]{xcolor}
\RequirePackage{tikz}
\usetikzlibrary{arrows.meta,positioning,shapes,fit,calc}
\RequirePackage{listings}

\RequirePackage{caption}
\captionsetup{font=small, labelfont=bf, labelsep=period, margin=1em}
\captionsetup[figure]{justification=centering}
\captionsetup[table]{position=top}
\captionsetup[lstlisting]{position=top, singlelinecheck=false, margin=0pt}
\renewcommand{\lstlistingname}{Листинг}

\counterwithin{figure}{section}
\counterwithin{table}{section}
\counterwithin{equation}{section}
\AddToHook{begindocument/end}{\counterwithin{lstlisting}{section}}

\lstdefinelanguage{SystemVerilog}[]{Verilog}{%
  morekeywords={logic,bit,byte,int,shortint,longint,always_ff,always_comb,always_latch,
    typedef,enum,struct,union,packed,interface,endinterface,modport,package,endpackage,
    import,unique,priority,automatic,localparam,return,break,continue,const,void,
    function,endfunction,task,endtask,genvar,generate,endgenerate,assert,property},
  sensitive=true}

\lstset{%
  basicstyle=\ttfamily\small,
  keywordstyle=\bfseries\color{MidnightBlue},
  commentstyle=\itshape\color{gray},
  stringstyle=\color{BrickRed},
  numbers=left, numberstyle=\tiny\color{gray}, numbersep=8pt,
  frame=tb, framerule=0.6pt, framesep=4pt,
  xleftmargin=1.5em, framexleftmargin=1.5em,
  columns=fullflexible, keepspaces=true,
  showstringspaces=false, tabsize=4,
  breaklines=true, breakatwhitespace=true,
  extendedchars=true,
  % без этого в XeLaTeX типографские символы в комментариях «уезжают»
  literate={«}{{\guillemotleft}}1 {»}{{\guillemotright}}1
           {—}{{---}}1 {–}{{--}}1 {№}{{\textnumero}}1,
}
% listings знает только символы до 0xFF, поэтому в XeLaTeX кириллица в
% комментариях и строках выводится без стиля. Объявляем её буквами.
\begingroup\catcode0=12
\gdef\itmo@lstcyr{\lst@CCECUse\lst@ProcessLetter
  абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ^^00}
\endgroup
\lst@AddToHook{SelectCharTable}{\itmo@lstcyr}
% Не отрывать подпись листинга от кода в конце страницы.
\RequirePackage{needspace}
\AddToHook{env/lstlisting/before}{\needspace{5\baselineskip}}

% ---------------------------------------------------------------- Ссылки
\RequirePackage[unicode, colorlinks, allcolors=MidnightBlue, linktoc=all]{hyperref}
\RequirePackage{etoolbox}
% Список литературы — в оглавление.
\apptocmd{\thebibliography}{\addcontentsline{toc}{section}{\refname}}{}{}
% Ненумерованный раздел с записью в оглавлении: \unnumberedsection{Введение}
\newcommand{\unnumberedsection}[1]{\section*{#1}\addcontentsline{toc}{section}{#1}}

% ---------------------------------------------------------------- Данные титульного листа
% \title — тема работы, \author — «И.\,О.~Фамилия»; остальные поля ниже.
% Шапка титульного листа. Пустые поля не выводятся.
\def\@ministry{Министерство науки и высшего образования Российской Федерации}
\def\@university{Национальный исследовательский университет ИТМО}
\def\@megafaculty{Мегафакультет компьютерных технологий и управления}
\def\@faculty{Факультет программной инженерии и компьютерной техники}
\def\@worktype{Отчет по лабораторной работе}
\def\@labnumber{}
\def\@discipline{}
\def\@group{}
\def\@supervisor{}
\def\@authorlabel{Выполнил студент группы}
\def\@supervisorlabel{Руководитель}
\def\@day{\hspace{1.5em}}
\def\@month{\hspace{4.5em}}
\def\@city{Санкт-Петербург}
\def\@reportyear{\the\year}

\newcommand{\ministry}[1]{\def\@ministry{#1}}
\newcommand{\university}[1]{\def\@university{#1}}
\newcommand{\megafaculty}[1]{\def\@megafaculty{#1}}
\newcommand{\faculty}[1]{\def\@faculty{#1}}
\newcommand{\worktype}[1]{\def\@worktype{#1}}
\newcommand{\labnumber}[1]{\def\@labnumber{#1}}
\newcommand{\discipline}[1]{\def\@discipline{#1}}
\newcommand{\group}[1]{\def\@group{#1}}
\newcommand{\supervisor}[1]{\def\@supervisor{#1}}
\newcommand{\authorlabel}[1]{\def\@authorlabel{#1}}   % «Выполнила студентка группы»
\newcommand{\supervisorlabel}[1]{\def\@supervisorlabel{#1}}
\newcommand{\reportdate}[2]{\def\@day{#1}\def\@month{#2}}   % \reportdate{15}{октября}
\newcommand{\city}[1]{\def\@city{#1}}
\newcommand{\reportyear}[1]{\def\@reportyear{#1}}

\pdfstringdefDisableCommands{\def\,{}}
\AtBeginDocument{\hypersetup{pdftitle={\@title}, pdfauthor={\@author}}}

% ---------------------------------------------------------------- Титульный лист
% Расположение и пропорции — как в отчётах в Word: шапка, тема, подписи, дата, город.
\newcommand{\@signrow}[2]{%
  #1 & \if@signatures\rule{3.5cm}{0.4pt}\fi & #2 \\
  \if@signatures & {\small(подпись)} & \\\fi}
% Подчёркивание на одном уровне независимо от «хвостов» букв (р, у, д).
\newcommand{\@uline}[1]{\underline{\raisebox{0pt}[\height][0pt]{#1}}}

\renewcommand{\maketitle}{%
  \hypersetup{pageanchor=false}%
  \begin{titlepage}
    \centering
    {\linespread{1.15}\selectfont
     \ifx\@ministry\@empty\else\@ministry\par\fi
     \@university\par
     \ifx\@megafaculty\@empty\else\@megafaculty\par\fi
     \@faculty\par}
    \linespread{1.4}\selectfont

    \vspace{0pt plus 2.4fill}
    \@worktype\ifx\@labnumber\@empty\else~№\,\@labnumber\fi\par
    \vspace{0.6em}
    \ifx\@discipline\@empty\else по курсу «\@discipline»\par\vspace{0.6em}\fi
    Тема: «\@title»\par

    \vspace{0pt plus 2fill}
    {\linespread{1.2}\selectfont
     \begin{tabular*}{\linewidth}{@{}l@{\extracolsep{\fill}}cr@{}}
       \@signrow{\@authorlabel\ifx\@group\@empty\else\ \@group\fi}{\@author}
       \noalign{\vspace{1.5em}}
       \@signrow{\@supervisorlabel}{\@supervisor}
     \end{tabular*}\par}

    \vspace{0pt plus 1.1fill}
    {\raggedleft\@uline{\@day}~\@uline{\@month} \@reportyear~г.\par}

    \vspace{0pt plus 1fill}
    \@city\par
    \@reportyear\par
  \end{titlepage}%
  \hypersetup{pageanchor=true}}

% Оглавление на отдельной странице (титульный лист не нумеруется, оглавление — с. 1).
% Строки кликабельны целиком, чёрным цветом, с точками до номера страницы.
\RequirePackage[titles]{tocloft}
\renewcommand{\cftsecleader}{\cftdotfill{\cftdotsep}}
\let\@origtoc\tableofcontents
\renewcommand{\tableofcontents}{{\hypersetup{linkcolor=black}\@origtoc}\clearpage}
