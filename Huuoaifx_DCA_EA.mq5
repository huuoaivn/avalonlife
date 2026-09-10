//+------------------------------------------------------------------+
//|                                          Huuoaifx_DCA_EA.mq5     |
//|  Modular Grid/DCA Multi-Signal Expert Advisor (MQL5)             |
//|                                                                    |
//|  KIEN TRUC MODULE (se duoc bo sung qua tung PHAN):                |
//|   PHAN 1 - Framework, Enum, Struct, Input, Init/Normalize (FILE NAY)|
//|   PHAN 2 - Signal Engine & Grid/DCA Engine                        |
//|   PHAN 3 - Risk Management: Martingale SL Recovery, Partial Close,|
//|            Hedging & Hedging Zone, Target Profit/Risk, Time Filter|
//|   PHAN 4 - Dashboard (HUD) Render Engine                          |
//|   PHAN 5 - OnTick Orchestration & Order Execution Layer           |
//+------------------------------------------------------------------+
#property copyright "Huuoaifx"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//======================================================================
// 1. ENUM DECLARATIONS
//======================================================================

// --- 1.1 Trade Execution Mode
enum ENUM_TRADE_EXECUTION
  {
   Buy_And_Sell,     // Buy And Sell (2 chieu doc lap)
   Buy_Or_Sell,      // Buy Or Sell (chi 1 chieu tai 1 thoi diem)
   Buy_Only,         // Buy Only
   Sell_Only         // Sell Only
  };

// --- 1.2 DCA Method
enum ENUM_DCA_METHOD
  {
   Fixed_Step,             // Fixed Step (khoang cach co dinh)
   Step_With_Timeframe,    // Step With Timeframe (theo khung thoi gian)
   Step_Multiplied,        // Step Multiplied (khoang cach nhan he so)
   Signal_Based,           // Signal Based (vao lenh DCA theo tin hieu)
   Positive_Pyramiding,    // Positive Pyramiding (nhoi lenh thuan xu huong)
   Dual_Pyramiding,        // Dual Pyramiding (nhoi lenh ca 2 chieu)
   Dual_Signal_Pyramiding, // Dual Signal Pyramiding (nhoi lenh 2 chieu theo tin hieu)
   Step_With_BarClose      // Step With BarClose (xac nhan dong nen)
  };

// --- 1.3 Lot Management Mode
enum ENUM_LOT_MODE
  {
   Fixed_Lot,              // Fixed Lot (LUON dung dung InpInitialLot, khong nhan/cong them)
   Lot_Multiplier,         // Lot Multiplier (nhan he so)
   Lot_Addition,           // Lot Addition (cong don)
   Custom_Lot_Sequence     // Custom Lot Sequence (chuoi tuy chinh "0.01-0.02-0.03")
  };

// --- 1.4 Hedging Balance Mode
enum ENUM_LOT_BALANCING
  {
   Independent_Lots,       // Independent Lots (Buy/Sell tinh lot doc lap)
   Chain_Lots              // Chain Lots (lot noi tiep theo tong chuoi)
  };

// --- 1.5 Signal Trigger Options
enum ENUM_SIGNAL_TRIGGER
  {
   CCI,                          // CCI
   Stochastic,                   // Stochastic
   Momentum,                     // Momentum
   Always_On,                    // Always On (khong loc tin hieu)
   Color_Candle,                 // Color Candle
   Supertrend,                   // Supertrend
   Random,                       // Random
   CCI_Reverse,                  // CCI Reverse
   Stoch_Reverse,                // Stochastic Reverse
   UTBOT_Signal,                 // UTBOT Signal
   Custom_iCustom,                // Custom iCustom Indicator
   RSI,                          // RSI
   RSI_Reverse,                  // RSI Reverse
   Ichimoku_Kumo_Breakout,       // Ichimoku Kumo Breakout
   Smart_Trend_Follow,           // Smart Trend Follow
   Smart_Trend_Reverse,          // Smart Trend Reverse
   Smart_Internal_Follow,        // Smart Internal Follow
   Smart_Internal_Reverse,       // Smart Internal Reverse
   Smart_Swing_Follow,           // Smart Swing Follow
   Smart_Swing_Reverse,          // Smart Swing Reverse
   Bollinger_Bands,              // Bollinger Bands
   Pinbar_Pattern,                // Pinbar Pattern
   Engulfing_Pattern,            // Engulfing Pattern
   Pinbar_Engulfing_Combo        // Pinbar + Engulfing Combo
  };

// --- 1.6 Applied Price Constants
enum ENUM_APPLIED_PRICE_CUSTOM
  {
   Price_Close,       // Close
   Price_Open,        // Open
   Price_High,        // High
   Price_Low,         // Low
   Price_Median,      // Median (H+L)/2
   Price_Typical,     // Typical (H+L+C)/3
   Price_Weighted     // Weighted (H+L+2C)/4
  };

// --- 1.7 Stochastic MA Methods
enum ENUM_STOCH_MA_METHOD
  {
   Mode_SMA,          // SMA
   Mode_EMA,          // EMA
   Mode_SMMA,         // SMMA
   Mode_LWMA          // LWMA
  };

// --- 1.8 Nguon Loi nhuan dung de Tia lenh Lien Chuoi / Tai khoan (Cross-Sequence Trim)
enum ENUM_CROSS_TRIM_SOURCE
  {
   Opposite_Sequence,     // Chi dung Loi nhuan duong cua Chuoi doi dien (Buy<->Sell)
   Daily_Realized_Profit, // Chi dung Loi nhuan DA CHOT trong ngay (Balance dau ngay)
   Both                   // Dung ca 2 nguon cong lai
  };

// --- 1.9 Truong Gia dung cho Stochastic (STO_LOWHIGH chuan hoac STO_CLOSECLOSE)
enum ENUM_STOCH_PRICE_FIELD
  {
   StochPrice_LowHigh,    // Low/High (chuan)
   StochPrice_CloseClose  // Close/Close
  };

// --- 1.10 Che do mo lenh Can bang Khoi luong (Lot Equalizer)
enum ENUM_EQUALIZER_MODE
  {
   Equalizer_Independent,      // Them lots doc lap (lenh rieng, tag #EQLZ)
   Equalizer_ChainedIntoSequence // Them lots vao chuoi (nhap thang vao chuoi dang it Lot hon)
  };

// --- 1.6 Trend Switch: kieu nguong "dang lo bao nhieu" moi xet kich hoat (Section 9.2c)
enum ENUM_TS_TRIGGER_MODE
  {
   TS_Trigger_PercentAccount,  // 1. % Tai khoan (Balance) dang am
   TS_Trigger_Pips,            // 2. Pip cua rieng chuoi dang lo
   TS_Trigger_Money            // 3. So tien cu the ($/cent) toan Tai khoan dang am
  };

//======================================================================
// 2. INPUT PARAMETERS
//======================================================================

//--- 2.1 CAI DAT CHUNG ------------------------------------------------
input group "===== CAI DAT CHUNG ====="
input bool                  InpCombineSameMagic  = false;           // Ket hop EA cung Magic?
input bool                  InpAllowManualOrders = true;             // Cho phep boi them lenh thu cong?
input long                  InpMagicNumber       = 9196;              // Magic Number, 0->Thu cong
input double                InpInitialLot        = 0.01;              // Lots
input double                InpVirtualTP_Pips    = 0.0;               // TP, pips (0->OFF, khong chot le tung lenh, chi chot ca chuoi)
input double                InpVirtualSL_Pips    = 0.0;               // SL, pips
input ENUM_TRADE_EXECUTION  InpTradeExecution    = Buy_And_Sell;      // Kieu mo lenh Buy-Sell
input bool                  InpBlockNewSideWhileOtherActive = true;   // KHONG mo CHUOI MOI o 1 ben khi ben KIA VAN CON ACTIVE (bat ke dang am/hoa von/duong, bat ke Trend Switch Bat/Tat) - CHI 1 chuoi (khong tinh Hedge, vi Hedge luon nguoc chieu va tu dong chot cung chuoi no bao ve) duoc mo tai 1 thoi diem; rieng Trend Switch (Section 9.2c) van duoc mo chuoi doi dien BINH THUONG khi du nguong - day la NGOAI LE duy nhat, khong bi chan boi dieu kien nay
input bool                  InpShowVirtualTP_Line= false;             // Hien thi TP?
input int                   InpClearOrderDelayMin= 0;                 // So phut delay sau khi clear lenh
input string                InpOrderComment      = "Huuoaifx DCA";   // Order Comment (nhan dien lenh cua EA)
input int                   InpSlippage          = 30;                // Slippage (points)
input bool                  InpAllowNewSequence  = true;              // Allow Open New Sequence

//--- 2.2 GIOI HAN ------------------------------------------------------
input group "===== GIOI HAN ====="
input int      InpMaxDCAOrders        = 100;   // So lenh buy toi da
input int      InpMaxSellOrders       = 100;   // So lenh sell toi da
input double   InpMaxSpreadPips       = 5.0;   // Spread toi da, pips
input double   InpMaxTotalLot         = 2.3;   // Lots toi da (0 = Khong gioi han)
input bool     InpNewCycleAtMaxLot    = false; // Bat New Cycle khi dat Lots toi da
input int      InpOpenOrderDelaySec   = 2;     // Thoi gian delay moi lan mo lenh, giay
input bool     InpUseMarginProtection = true;  // Bat bo loc Margin Level an toan?
input double   InpMinMarginLevel      = 200.0; // Margin Level toi thieu (%) de cho phep nhoi them DCA

//--- 2.3 CHE DO XO SO (LOTTERY / HIGH-RISK MODE) -----------------------
input group "===== CHE DO XO SO ====="
input bool     InpEnableLotteryMode       = false; // Su dung che do xo so?
input double   InpLotterySLMultiplier     = 2.0;   // He so nhan khi SL
input int      InpLotteryDelayAfterSLTP_Min = 60;  // Thoi gian delay sau khi SL-TP, phut
input double   InpLotteryCutLossReset     = 0.0;   // So tien cat lo va reset chuoi xo so (0->OFF)
input double   InpLotteryTargetMultiplier = 2.0;   // Target Multiplier tong Equity (vd x2, x3 - 0=Tat)
input double   InpLotteryLotMultiplier    = 1.5;   // He so nhan Lot moi lenh khi bat Xo So

//--- 2.4 DCA -------------------------------------------------------------
input group "===== DCA ====="
input bool                InpUseDCA               = true;               // Su dung DCA?
input bool                InpUseDCATrendFilter    = false;               // Su dung bo loc trend cho DCA
input int                 InpDCATrendFilterActivateCount = 20;           // So lenh kich hoat bo loc trend cho DCA
input ENUM_DCA_METHOD     InpDCAMethod            = Step_With_BarClose;  // Chon kieu DCA
input int                 InpDCAMethodSwitchCount = 0;                   // So lenh kich hoat kieu DCA moi (0->OFF)
input ENUM_DCA_METHOD     InpDCAMethodAlt         = Step_With_Timeframe; // Chon kieu DCA moi
input ENUM_LOT_MODE       InpLotMode              = Fixed_Lot; // Chon he so lots DCA
input double               InpLotMultiplier        = 1.2;                // He so nhan ban dau
input bool                 InpUseLotMultiplierTiers= false;               // Su dung thay doi he so nhan moi?
input int                  InpLotMultTier1Count    = 10;   // 1.So lenh kich hoat he so nhan moi
input double                InpLotMultTier1Value    = 1.2;  // 1.He so nhan moi
input int                  InpLotMultTier2Count    = 20;   // 2.So lenh kich hoat he so nhan moi
input double                InpLotMultTier2Value    = 1.1;  // 2.He so nhan moi
input int                  InpLotMultTier3Count    = 30;   // 3.So lenh kich hoat he so nhan moi
input double                InpLotMultTier3Value    = 1.05; // 3.He so nhan moi
input int                  InpLotMultTier4Count    = 40;   // 4.So lenh kich hoat he so nhan moi
input double                InpLotMultTier4Value    = 1.06; // 4.He so nhan moi
input int                  InpLotMultTier5Count    = 50;   // 5.So lenh kich hoat he so nhan moi
input double                InpLotMultTier5Value    = 1.03; // 5.He so nhan moi
input double                InpLotAdditionStep      = 0.01; // He so cong
input string                InpCustomLotSequence    = "0.01-0.02-0.03-0.03-0.04-0.05-0.08-0.08-0.09-0.09-0.1-0.11-0.12-0.15-0.18"; // 1.He so thu cong
input string                InpCustomLotSequence2   = "0.18-0.19-0.2-0.23-0.25-0.28-0.34-0.38-0.45-0.62-0.68-0.78-1.23-2.5";   // 2.He so thu cong (noi tiep sau khi het chuoi 1)
input bool                  InpCustomLotMinPrevious = true; // Lots thu cong toi thieu bang lots lien truoc?
input double                InpStepMultiplierFactor = 1.2;  // He so nhan khoang cach ban dau
input double                InpFixedStepPips        = 30.0; // 0.Khoang cach nhoi lenh ban dau
input double                InpDCAOrderTP_Pips      = 0.0;  // TP don lenh (0->TP chuoi)
input double                InpChainTP_Pips         = 50.0; // TP chuoi DCA, pips
input bool                  InpUseDynamicChainTP    = true;  // Tu dong giam TP chuoi khi so lenh tang cao?
input int                   InpDynamicTPStartOrder  = 7;     // So lenh bat dau giam TP chuoi
input double                InpDynamicTPReducedPips = 5.0;   // TP chuoi khi da vuot moc (pips, keo ve sat hoa von)
input bool                  InpUseDynamicGridStep   = true;  // Su dung Khoang cach Grid da tang theo moc so lenh
input int                   InpGridStepTier1Count   = 5;    // 1.So lenh tang khoang cach nhoi
input double                InpGridStepTier1Pips    = 30.0; // 1.Khoang cach nhoi lenh
input int                   InpGridStepTier2Count   = 10;   // 2.So lenh tang khoang cach nhoi
input double                InpGridStepTier2Pips    = 30.0; // 2.Khoang cach nhoi lenh
input int                   InpGridStepTier3Count   = 15;   // 3.So lenh tang khoang cach nhoi
input double                InpGridStepTier3Pips    = 30.0; // 3.Khoang cach nhoi lenh
input int                   InpGridStepTier4Count   = 20;   // 4.So lenh tang khoang cach nhoi
input double                InpGridStepTier4Pips    = 30.0; // 4.Khoang cach nhoi lenh
input string                InpDynamicGridSteps     = "";   // (Nang cao) Bang tier tuy chinh "Moc:Pips,..." - de trong = dung 4 tier tren
input ENUM_TIMEFRAMES       InpStepTimeframe        = PERIOD_H1;  // Timeframe (Step_With_Timeframe)
input double                InpMaxStepPips          = 1000; // Gioi han Step toi da (Pips, 0 = Khong gioi han)
input bool                  InpRequireBarClose      = true;  // Yeu cau xac nhan dong nen (Step_With_BarClose)

//--- 2.4b DCA THEO ATR (UPGRADE v3.0.6, phan tich tu Can Cu Bu Sieng Nang) - CHI ap dung
//         cho kieu DCA "Step + Dong nen" (gia tri 7): khi thi truong bien dong manh, khoang
//         cach nhoi toi thieu se duoc NANG LEN theo ATR thay vi giu co dinh 1 con so pip
//         duy nhat. San toi thieu (0.Khoang cach nhoi lenh ban dau / Dynamic Grid Step)
//         LUON duoc giu nguyen - ATR chi lam TANG THEM khi vuot nguong "bao gia".
input group "===== DCA THEO ATR (Step + Dong nen - UPGRADE v3.0.6) ====="
input bool                  InpDCA_UseATRDistance   = true;   // Nang khoang cach nhoi theo ATR khi bien dong manh?
input int                   InpDCA_ATR_Period       = 14;     // ATR Period (dung rieng cho DCA)
input ENUM_TIMEFRAMES       InpDCA_ATR_Timeframe    = PERIOD_CURRENT; // ATR Timeframe (dung rieng cho DCA)
input double                InpDCA_ATR_StormPips    = 60.0;   // Nguong ATR, pips - vuot nguong nay moi coi la "bien dong manh"
input double                InpDCA_ATR_Multiplier   = 1.5;    // He so nhan ATR -> Khoang cach nhoi khi bien dong manh
input bool                  InpUseVelocityStep      = true;   // Keo gian khoang cach khi nen giat qua nhanh?
input double                InpVelocityRatio        = 2.0;    // He so nhan Step khi nen hien tai dai gap X lan ATR (dung chung lam ca Nguong VA He so nhan)

//--- 2.4c BO LOC ADX CHO DCA (UPGRADE v3.0.6) - AND-gate bo sung CHI cho DCA (khong anh
//         huong tin hieu vao lenh dau tien Entry): chi cho nhoi them khi Trend du manh.
input group "===== BO LOC ADX CHO DCA (UPGRADE v3.0.6) ====="
input bool                  InpUseADXFilter         = true;   // Su dung bo loc ADX cho DCA?
input ENUM_TIMEFRAMES       InpADX_Timeframe        = PERIOD_CURRENT; // ADX Timeframe
input int                   InpADX_Period           = 14;     // ADX Period
input double                InpADX_MinLevel         = 18.0;   // ADX toi thieu de cho phep nhoi them

//--- 2.4d BO LOC ATR AN TOAN CHO DCA (UPGRADE v3.0.6) - chan nhoi khi bien dong QUA THAP
//         (danh vong, de bi nhoi lien tuc vo ich) HOAC QUA CAO (cuc doan/tin soc). Doc
//         lap voi "DCA theo ATR" o tren (khong lam thay doi khoang cach nhoi, chi CHAN/CHO).
input group "===== BO LOC ATR AN TOAN CHO DCA (UPGRADE v3.0.6) ====="
input bool                  InpUseATRFilter         = true;   // Su dung bo loc ATR an toan cho DCA?
input double                InpATR_MinPips          = 3.0;    // ATR toi thieu, pips (0 = Khong gioi han duoi)
input double                InpATR_MaxPips          = 400.0;  // ATR toi da, pips (0 = Khong gioi han tren)

//--- 2.4e BO LOC TIN TUC (UPGRADE v3.0.6) - Tam dung mo lenh MOI (Entry + DCA) quanh cac
//         tin kinh te quan trong, dung Economic Calendar noi bo cua MT5 (khong can ket noi
//         Internet rieng, Broker/Terminal cung cap san). Chi loc tin cua Hoa Ky (USD) -
//         phu hop XAUUSD (Vang bien dong manh nhat theo du lieu USD).
input group "===== BO LOC TIN TUC (UPGRADE v3.0.6) ====="
input bool                  InpUseNewsFilter        = true;   // Su dung bo loc tin tuc?
input bool                  InpNewsHighImpactOnly   = true;   // Chi loc tin Anh huong CAO (High Impact)?
input int                   InpNewsMinutesBefore    = 15;     // So phut TRUOC tin tam dung mo lenh
input int                   InpNewsMinutesAfter     = 15;     // So phut SAU tin tam dung mo lenh

//--- 2.4f CHONG DON CUC GIA & GIOI HAN LENH/NEN (UPGRADE v3.0.6) - "Chong san bop lenh":
//         tu choi mo lenh neu gia qua gan 1 lenh KHAC da co san (tranh Requote/Slippage
//         khien nhieu lenh don cuc 1 vung gia); va gioi han so lenh moi toi da trong 1 nen.
input group "===== CHONG DON CUC GIA & GIOI HAN LENH/NEN (UPGRADE v3.0.6) ====="
input bool                  InpUseAntiCluster       = true;   // Chong don cuc gia (tu choi neu qua gan 1 lenh da co)?
input double                InpAntiClusterMinPips   = 10.0;   // Khoang cach toi thieu voi BAT KY lenh nao da co, pips
input bool                  InpUseMaxOrdersPerBar   = true;   // Gioi han so lenh moi (Entry+DCA) trong 1 nen?
input int                   InpMaxOrdersPerBar      = 1;      // So lenh toi da moi nen (an toan, chong qua tai)

//--- 2.5 DIEU CHINH TP CHUOI KHI AM --------------------------------------
input group "===== DIEU CHINH TP CHUOI KHI AM ====="
input bool     InpUseEmergencyTP        = false;    // Dieu chinh TP chuoi khi am?
input double   InpAdjustNegativePercent = -20.0;    // Phan tram am, -% (0->OFF)
input double   InpAdjustNegativeMoney   = -12000.0; // So tien am, -$ (0->OFF)
input double   InpAdjustedTP_Pips       = 10.0;     // TP chuoi DCA sau khi dieu chinh

//--- 2.6 MO LENH NGUOC CHIEU ----------------------------------------------
input group "===== MO LENH NGUOC CHIEU ====="
input bool     InpUseOppositeOrder      = false; // Mo lenh nguoc chieu?
input int      InpOppositeActivateCount = 12;    // So lenh kich hoat mo lenh nguoc chieu
input double   InpOppositeLotPercent    = 15.0;  // Phan tram lots lenh nguoc chieu so voi tong lots (0->Fix lots)
input double   InpOppositeFixLot        = 0.01;  // Fix Lots cua lenh nguoc chieu

//--- 2.7 TIA LENH CUNG CHUOI ----------------------------------------------
input group "===== TIA LENH CUNG CHUOI ====="
input bool     InpUseAdvancedTrim           = false; // Su dung tia lenh
input bool     InpTrimIgnoreMagic           = false; // Tia lenh cung chuoi khong quan tam Magic
input int      InpMinOrdersToTrim           = 20;    // So lenh kich hoat tia lan dau
input int      InpTrimActivateFrom2nd       = 15;    // So lenh kich hoat tia tu lan 2
input int      InpTrimFirstOrdersNeeded     = 2;     // So lenh dau can tia
input int      InpTrimLastOrdersMax         = 0;     // So lenh cuoi toi da dung de tia, 0->Auto
input double   InpTrimProfitPercentAfter    = 10.0;  // % tien loi sau khi tia (0->So tien loi sau khi tia)
input double   InpTrimProfitMoneyAfter      = 10.0;  // So tien loi sau khi tia
input double   InpPostTrimTP_Pips           = 5.0;   // TP chuoi sau khi tia, pips (dung chung tia lenh 1 phan)
input double   InpPostTrimLotMultiplier     = 1.15;  // He so nhan sau khi tia (dung chung tia lenh 1 phan)
input bool     InpTrimUseNewestProfit       = true;  // true: dung Loi nhuan lenh MOI NHAT de bu lenh am nang nhat
input double   InpTrimClosePercent          = 50;    // % Volume dong khi InpTrimUseNewestProfit=false
input bool     InpUsePartialTrim            = false; // Su dung tia lenh 1 phan
input double   InpPartialTrimNegPercent     = -30.0; // % am kich hoat tia lenh 1 phan
input int      InpPartialTrimActivateCount  = 20;    // So lenh kich hoat tia lenh 1 phan
input double   InpPartialTrimFirstLotPercent= 30.0;  // Phan tram lots lenh dau de tia
input double   InpPartialTrimProfitPercentAfter = 20.0; // Phan tram tien loi sau tia (0->So tien loi sau khi tia)
input double   InpPartialTrimProfitMoneyAfter   = 10.0; // So tien loi sau khi tia
input int      InpPartialTrimLastOrdersMax  = 3;     // So lenh cuoi toi da dung de tia, 0->Auto

//--- 2.8 TIA LENH KHAC CHUOI -----------------------------------------------
input group "===== TIA LENH KHAC CHUOI ====="
input bool     InpUseCrossSequenceTrim   = false;               // Su dung tia lenh khac chuoi
input bool     InpCrossTrimFilterMagicPair = false;              // Loc dung Magic-Pair
input int      InpCrossTrimActivateCount = 25;                  // Tong lenh kich hoat tia
input int      InpCrossTrimFirstOrdersNeeded = 1;                // So lenh dau can tia
input int      InpCrossTrimLastOrdersMax = 5;                    // So lenh cuoi dung de tia (0->Auto)
input double   InpCrossTrimProfitAfter   = 10.0;                 // So tien lai sau tia
input ENUM_CROSS_TRIM_SOURCE InpCrossTrimSourceMode = Both;      // Nguon loi nhuan dung de bu
input bool     InpCrossTrimUseDailyProfit = false;                // Su dung lai da chot trong ngay de tia lenh
input bool     InpCrossTrimUsePartialSameDir = false;             // Su dung tia lenh 1 phan lenh cung chieu
input double   InpCrossTrimPartialMinLot  = 0.1;                  // Min lots kich hoat tia 1 phan
input double   InpCrossTrimPartialPercent = 35.0;                 // Phan tram lots can tia
input double   InpCrossTrimMinReserve    = 0;     // Giu lai toi thieu (Tien te tai khoan) tu nguon, khong dung het

//--- 2.9 CAN LOTS -----------------------------------------------------------
input group "===== CAN LOTS ====="
input bool     InpUseLotEqualizer = false;             // Su dung can lots?
input ENUM_EQUALIZER_MODE InpEqualizerMode = Equalizer_Independent; // Che do can lots
input double   InpLotDiffTrigger  = 6.0;                // So lots chenh lech kich hoat can lots
input double   InpLotDiffStop     = 2.0;                // So lots chenh lech dung can lots
input double   InpBalancingLot    = 0.1;                // Lots mo them
input int      InpEqualizerDelaySec = 120;              // Do tre moi lan them lots, giay

//--- 2.10 HEDGING ZONE -------------------------------------------------------
input group "===== HEDGING ZONE ====="
input bool     InpUseHedgingZone            = false;  // Su dung Hedging Zone?
input int      InpHedgeZoneActivateCount    = 20;     // So lenh kich hoat Hedging Zone
input double   InpHedgeZoneLotMultiplier    = 2.0;    // He so nhan tong lots
input double   InpHedgeZoneBandPips         = 35.0;   // Vung mo lenh hedging, pips
input double   InpHedgeZoneCloseMoney       = 1000.0; // So tien chot tong, $ (0->Pips TP tong)
input double   InpHedgeZoneClosePips        = 50.0;   // Pips TP tong lots chenh lech
input int      InpHedgeZoneNewMoneyActivateCount = 26; // Tong lenh kich hoat so tien chot tong moi
input double   InpHedgeZoneNewMoney         = 100.0;  // So tien chot tong moi, $
input double   InpHedgeZoneMaxLot           = 20.0;   // Max lots hedging zone

//--- 2.11 HEDGING -------------------------------------------------------------
input group "===== HEDGING ====="
input bool     InpUseHedging             = true;  // Su dung hedging
input int      InpHedgeActivateCount     = 5;     // So lenh kich hoat hedging (0->OFF)
input double   InpHedgePercent           = -25.0; // Phan tram kich hoat hedging (0->OFF)
input bool     InpHedgeUseDCALotForHedge = false; // Su dung lots DCA mo lots hedging (false->Phan tram lots hedging)
input double   InpHedgeLotMultiplier     = 20.0;  // Phan tram lots hedging
input double   InpHedgeTP_Money          = 10.0;  // TP hedging, pips
input double   InpHedgeTotalTPMoney      = 50.0;  // So tien TP tong khi hedging, $
input bool     InpHedgeStopTrimWhileActive = true; // Dung tia lenh khi hedging?
input double   InpHedgeZoneTriggerPercent= 5.0;   // (Nang cao) Nguong % Drawdown/Balance bo sung de kich hoat Hedge
input double   InpHedgeSL_Money          = 0;     // SL rieng cho lenh Hedge (Tien te tai khoan, 0 = Tat)
input double   InpHedgeCloseMinProfit    = 10.0;  // Loi nhuan TOI THIEU ($/cent) khi chot chung Chuoi + Hedge nguoc chieu (0 = Tat, chot ngay khi hit Pips nhu cu)

//--- 2.12 RESET LOTS (THU CONG) ------------------------------------------------
input group "===== RESET LOTS (THU CONG) ====="
input double   InpManualResetLot      = 0.1;  // Reset lots
input double   InpResetLotMultiplier  = 1.2;  // He so nhan sau khi reset
input double   InpResetChainTP_Pips   = 5.0;  // TP chuoi sau khi reset

//--- 2.13 CAI DAT DONG LENH -----------------------------------------------------
input group "===== CAI DAT DONG LENH ====="
input double   InpCloseAllPercentDiff = 0.0;   // % lai/lo giua buy va sell de Close All (0->OFF)
input bool     InpUseAccountTP        = true;  // Money TP All account, +$ (0->OFF) - chot CA 2 chuoi khi TONG du tien
input double   InpAccountTP_Value     = 50.0;  // Money TP All account, +$, 0->OFF
input bool     InpUseAccountSL        = true;  // BAT/TAT SL Lop 1 (Toan tai khoan) - LUOI AN TOAN CUOI CUNG, doc lap voi Trend Switch/ADX/tin hieu, luon cat khi cham nguong du bat cu ly do gi
input double   InpAccountSL_Value     = 30.0;  // TU NHAP SO % (hoac So tien, xem dong ben duoi) Cat lo Lop 1 o day - mac dinh 30 (= -30% Balance), doi thanh so ban muon
input bool     InpAccountTP_IsPercent = false; // true = % Balance, false = Money
input bool     InpAccountSL_IsPercent = true;  // true = So o tren la % Balance (mac dinh), false = So o tren la Tien co dinh ($/cent)
input bool     InpUseAccountSL_Money      = true;     // Money SL All account - LOP 2 (theo SO TIEN CU THE, VD 30000 = -30.000$/cent) - DOC LAP voi Lop 1 o tren, bat CA 2 cung luc = 2 lop bao ve song song, cham lop nao truoc thi Dong toan bo truoc
input double   InpAccountSL_MoneyValue    = 30000.0;  // Muc SL Lop 2 theo SO TIEN CU THE (tien te tai khoan - $ hoac cent tuy loai tai khoan cua ban), 0->OFF
input bool     InpUseBuyTP            = true;  // Money TP Buy, +$ (0->OFF) - chot CA CHUOI Buy khi dat du tien
input double   InpBuyTP_Value         = 50.0;  // Money TP Buy, +$, 0->OFF
input bool     InpUseBuySL            = false; // Money SL Buy, -$ (0->OFF)
input double   InpBuySL_Value         = 0.0;   // Money SL Buy, -$, 0->OFF
input bool     InpBuyTP_IsPercent     = false;
input bool     InpBuySL_IsPercent     = false;
input bool     InpUseSellTP           = true;  // Money TP Sell, +$ (0->OFF) - chot CA CHUOI Sell khi dat du tien
input double   InpSellTP_Value        = 50.0;  // Money TP Sell, +$, 0->OFF
input bool     InpUseSellSL           = false; // Money SL Sell, -$ (0->OFF)
input double   InpSellSL_Value        = 0.0;   // Money SL Sell, -$, 0->OFF
input bool     InpSellTP_IsPercent    = false;
input bool     InpSellSL_IsPercent    = false;
input bool     InpMoneyTPAllOnDCASignalCond = false; // Money TP All khi mo lenh DCA Signal am hoac xuat hien ca buy va sell

//--- 2.14 MUC TIEU LOI NHUAN NGAY ------------------------------------------------
input group "===== MUC TIEU LOI NHUAN NGAY ====="
input bool     InpUseDailyTarget           = false; // Su dung Target Loi nhuan Ngay
input double   InpDailyTarget_Value        = 0.0;   // So tien Muc tieu loi nhuan hang ngay, $ (0->OFF)
input double   InpDailyLossLimit           = 0.0;   // So tien Gioi han thua lo hang ngay, -$ (0->OFF)
input double   InpDailyTarget_PercentValue = 0.0;   // Phan tram Muc tieu loi nhuan hang ngay, % (0->OFF)
input double   InpDailyLossLimitPercent    = 0.0;   // Phan tram Gioi han thua lo hang ngay, -% (0->OFF)
input int      InpDailyNewDayDelayMin      = 120;   // So phut delay ngay moi
input bool     InpDailyTarget_IsPercent    = false;  // (noi bo) true = uu tien cap % o tren, false = uu tien cap $
input bool     InpStopTradingOnDailyTarget = true;   // Dung mo Chuoi moi/DCA them trong ngay khi da dat Target

//--- 2.15 MUC TIEU LOI NHUAN BAC THANG ---------------------------------------------
input group "===== MUC TIEU LOI NHUAN BAC THANG ====="
input bool     InpUseStaircaseTarget      = false;   // Su dung muc tieu loi nhuan bac thang?
input double   InpStaircaseTargetMoney    = 2000.0;  // So tien Muc tieu loi nhuan bac thang, $
input bool     InpStaircaseFilterMagicPair= true;    // Loc dung Magic-Pair?
input int      InpStaircaseCloseDelayMin  = 5;       // So phut delay sau khi dong lenh

//--- 2.16 TRAILING -----------------------------------------------------------------
input group "===== TRAILING ====="
input bool     InpUseTrailingStop     = false;     // Su dung trailing chuoi DCA?
input double   InpTrailingTriggerPips = 10.0;      // Pips bat dau trailing
input double   InpTrailingStepPips    = 2.0;       // Buoc trailing, pips
input double   InpTrailingFirstSLPips = 2.0;       // Diem dat SL cho lan dau trailing, pips
input bool     InpShowTrailingLine    = true;      // Hien thi line bat dau trailing?
input double   InpTrailingStopPips    = 50;        // (Nang cao) Khoang cach giu Gia hien tai - duong Trailing Stop, pips
input color    InpTrailingLineColor   = clrOrange; // (Nang cao) Mau duong Trailing Stop ve tren Chart

//--- 2.17 GIOI HAN THOI GIAN (GIO PC/LAPTOP) -----------------------------------------
input group "===== GIOI HAN THOI GIAN THEO GIO PC/LAPTOP ====="
input bool     InpUseTimeFilter   = false;    // Su dung gioi han thoi gian?
input bool     InpSession1_Enable = true;     // Su dung gioi han thoi gian 1
input string   InpSession1_Start  = "08:30";  // 1.Gio bat dau
input string   InpSession1_End    = "12:30";  // 1.Gio ket thuc
input bool     InpSession2_Enable = true;     // Su dung gioi han thoi gian 2
input string   InpSession2_Start  = "14:30";  // 2.Gio bat dau
input string   InpSession2_End    = "18:30";  // 2.Gio ket thuc
input bool     InpSession3_Enable = true;     // Su dung gioi han thoi gian 3
input string   InpSession3_Start  = "20:30";  // 3.Gio bat dau
input string   InpSession3_End    = "23:30";  // 3.Gio ket thuc
input bool     InpSession4_Enable = true;     // Su dung gioi han thoi gian 4
input string   InpSession4_Start  = "02:30";  // 4.Gio bat dau
input string   InpSession4_End    = "05:30";  // 4.Gio ket thuc
input bool     InpAllowDCAOutsideSession = true; // DCA ngoai thoi gian?

//--- 2.17b LICH GIAO DICH THEO NGAY TRONG TUAN (UPGRADE v3.0.6) - "Active gio vang, nghi
//          gio xau": doc lap voi 4 khung gio trong ngay o tren, tinh theo GIO MAY TINH.
input group "===== LICH GIAO DICH THEO NGAY TRONG TUAN (UPGRADE v3.0.6) ====="
input bool     InpUseWeeklySchedule = true;   // Su dung lich theo ngay trong tuan?
input bool     InpTradeMonday       = true;   // Giao dich Thu Hai?
input bool     InpTradeTuesday      = true;   // Giao dich Thu Ba?
input bool     InpTradeWednesday    = true;   // Giao dich Thu Tu?
input bool     InpTradeThursday     = true;   // Giao dich Thu Nam?
input bool     InpTradeFriday       = true;   // Giao dich Thu Sau?
input bool     InpTradeSaturday     = false;  // Giao dich Thu Bay? (Vang thuong dong cua)
input bool     InpTradeSunday       = false;  // Giao dich Chu Nhat? (Thanh khoan thap dau tuan)

//--- 2.18 DIEU KIEN MO LENH -----------------------------------------------------------
input group "===== DIEU KIEN MO LENH ====="
input ENUM_SIGNAL_TRIGGER      InpEntrySignal    = Supertrend;      // Chon tin hieu mo lenh
input ENUM_SIGNAL_TRIGGER      InpDCASignal      = Always_On;       // Tin hieu DCA (dung cho kieu DCA Signal_Based)
input ENUM_TIMEFRAMES           InpSignalTimeframe= PERIOD_CURRENT; // Chon TF mo lenh
input bool                      InpCloseOnTrendReversal = false;    // Dong lenh khi dao trend? (RSI-EMA-MACD)

input group "===== CHUYEN HUONG NHOI KHI DAO CHIEU MANH (Trend Switch) ====="
input bool                 InpUseTrendSwitch          = true;                     // Bat Trend Switch (dong bang chieu dang lo + duoi xu huong bang chieu doi dien)
input ENUM_TS_TRIGGER_MODE InpTrendSwitchTriggerMode  = TS_Trigger_PercentAccount; // Kieu nguong "dang lo bao nhieu" moi xet kich hoat (chon 1 trong 3)
input double                InpTrendSwitchPercent      = 10.0;    // (Kieu 1) Tai khoan am toi thieu bao nhieu % Balance moi xet kich hoat
input double                InpTrendSwitchMinLossPips  = 50.0;    // (Kieu 2) Rieng chuoi dang lo toi thieu bao nhieu Pip (tinh tu Gia trung binh) moi xet kich hoat
input double                InpTrendSwitchMoneyLoss    = 10000.0; // (Kieu 3) Tai khoan am toi thieu bao nhieu tien ($/cent) moi xet kich hoat
input double                InpTrendSwitchADXEnter     = 25.0;    // Nguong ADX (xu huong moi phai đủ MANH) moi cho phep kich hoat Trend Switch
input bool                  InpTrendSwitchUseADXExit   = true;    // Cho phep huy Trend Switch khi ADX yeu di (thi truong on dinh/di ngang)
input double                InpTrendSwitchADXExit      = 20.0;    // Nguong ADX rot xuong duoi muc nay -> coi la "on dinh", tu dong huy Trend Switch
input bool                  InpTrendSwitchUseTimeFallback = true;   // Bat "Gia han thoi gian" - qua thoi gian duoi day, du ADX CHUA manh (chua toi 25) van cho kich hoat bao ve (chong truong hop thi truong "lu lu" di 1 chieu, khong bien dong manh, ADX khong bao gio len duoc)
input double                InpTrendSwitchGraceMinutes    = 60.0;   // Gia han CO BAN (phut) - ap dung khi lo VUA CHAM nguong (xem InpUseTrendSwitchAdaptiveGrace de tu dong rut ngan khi lo cang sau)
input bool                  InpUseTrendSwitchAdaptiveGrace = true;  // Bat Gia han THICH UNG: lo cang VUOT XA nguong goc thi Gia han cang tu dong RUT NGAN (phan ung nhanh hon khi nguy hiem tang), thay vi dung 1 con so co dinh cho moi muc do lo
input double                InpTrendSwitchGraceMinMinutes  = 10.0;  // Gia han THAP NHAT (phut) - ap dung khi lo da dat/vuot InpTrendSwitchGraceSeverityCap lan nguong goc (chi co tac dung khi InpUseTrendSwitchAdaptiveGrace=true)
input double                InpTrendSwitchGraceSeverityCap = 2.0;   // Lo dat bao nhieu LAN nguong goc (VD 2.0 = gap doi nguong) thi Gia han giam toi muc THAP NHAT o tren - giua nguong goc (x1) va muc nay noi suy tuyen tinh

input bool                  InpUseTrendSwitchStallExit    = true;   // Them dieu kien THOAT Trend Switch khi chuoi dang DUOI XU HUONG (chasing) HET DA - khong tao them LOI NHUAN DINH MOI trong 1 thoi gian dai - doc lap hoan toan voi ADX va tin hieu dao chieu (bat ke chi bao tin hieu co phan ung kip hay khong)
input double                InpTrendSwitchStallMinutes    = 90.0;   // So PHUT KHONG co Loi nhuan dinh MOI (chuoi dang duoi xu huong) truoc khi coi la "thi truong het da/di ngang" va cho THOAT Trend Switch (chi tinh tu khi chuoi da tung co lai, tranh chot non lenh vua mo)

input bool                  InpTSPyramidFixedLot          = true;   // Chuoi DANG DUOI XU HUONG (Trend Switch chasing) dung LOT CO DINH (= Lot cua lenh dau tien) cho MOI lan nhoi them, KHONG nhan He so tang dan nhu DCA thuong - tranh tinh trang lenh nhoi sau cung (thuong to nhat) lai nam o diem gia XA NHAT, de "mac ket" neu dao chieu dot ngot (Khong anh huong DCA thuong / Positive Pyramiding doc lap)
input int                   InpTSPyramidMaxLegs           = 6;      // So lenh TOI DA cho MOI DOT nhoi cua chuoi DANG DUOI XU HUONG (0 = khong gioi han) - day DOT thi TAM DUNG (xem InpTSPyramidAllowNextBatch de mo DOT tiep theo) (Khong anh huong DCA thuong / Positive Pyramiding doc lap)
input bool                  InpTSPyramidAllowNextBatch    = true;   // Sau khi day 1 DOT (InpTSPyramidMaxLegs lenh) va TAM DUNG, co cho MO DOT TIEP THEO khong? Chi mo dot moi khi DU CA 3: (1) da nghi >= InpTSPyramidBatchPauseMinutes, (2) chuoi GOC (dang dong bang, phia doi dien) VAN con am du dung nguong Trend Switch, (3) tin hieu dao chieu VAN con xac nhan lai. Neu TAT: dot dau la TRAN CUNG, dung han vinh vien cho lan duoi nay.
input double                InpTSPyramidBatchPauseMinutes = 20.0;   // Thoi gian NGHI toi thieu (phut) giua 2 DOT nhoi lien tiep cua chuoi dang duoi xu huong (chi co tac dung khi InpTSPyramidAllowNextBatch=true) - tranh mo DOT moi ngay lap tuc, danh thoi gian danh gia lai tinh hinh

input group "--- Bo loc RSI ---"
input bool                      InpUseRSIFilter    = true;          // Su dung bo loc RSI
input ENUM_TIMEFRAMES           InpRSIFilter_TF    = PERIOD_CURRENT; // RSI TF
input ENUM_APPLIED_PRICE_CUSTOM InpRSIFilter_Price = Price_Close;    // RSI Price
input int                       InpRSIFilter_Period= 50;             // RSI Period
input double                    InpRSIFilter_LevelUp = 50.0;         // RSI Up Level
input double                    InpRSIFilter_LevelDown = 50.0;       // RSI Down Level

input group "--- Bo loc EMA ---"
input bool               InpUseEMAFilter  = false;          // Su dung bo loc EMA
input ENUM_TIMEFRAMES    InpEMA_Timeframe = PERIOD_CURRENT;   // Chon TF cho EMA
input int                InpEMA_Period    = 34;              // EMA 1
input int                InpEMA2_Period   = 89;              // EMA 2
input double              InpEMA_MaxDistPips = 500.0;         // Max khoang cach gia va EMA 1, pips
input double              InpEMA_MinGapPips   = 50.0;         // Min khoang cach EMA 1 va EMA 2, pips

input group "--- Bo loc MACD ---"
input bool     InpUseMACDFilter   = false;                    // Su dung bo loc MACD
input ENUM_TIMEFRAMES InpMACD_Timeframe = PERIOD_CURRENT;      // TF MACD
input int      InpMACD_FastEMA    = 30;                        // MACD Fast EMA
input int      InpMACD_SlowEMA    = 50;                        // MACD Slow EMA
input int      InpMACD_SMA        = 5;                         // MACD SMA
input ENUM_APPLIED_PRICE_CUSTOM InpMACD_Price = Price_Typical;  // Applied price MACD

input group "--- Bo loc Zone Cycle ---"
input bool     InpUseZoneCycle       = false;   // Su dung Zone Cycle?
input double   InpZoneCyclePriceUpper= 5000.0;  // Vung gia tren
input double   InpZoneCyclePriceLower= 4000.0;  // Vung gia duoi

//--- 2.19 CAC CHI BAO (INDICATORS) --------------------------------------------------
input group "===== INDI CCI ====="
input int      InpCCI_Period      = 14;    // CCI Period
input ENUM_APPLIED_PRICE_CUSTOM InpCCI_Price = Price_Close; // CCI Price
input int      InpCCI_LevelUp     = 100;   // CCI Qua mua
input int      InpCCI_LevelDown   = -100;  // CCI Qua ban

input group "===== INDI STOCH ====="
input int                     InpStoch_K         = 5;         // Stoch K Period
input int                     InpStoch_D         = 3;         // Stoch D Period
input int                     InpStoch_Slowing   = 3;         // Stoch Slowing
input ENUM_STOCH_MA_METHOD    InpStoch_MAMethod  = Mode_SMA;  // Stoch MA Method
input ENUM_STOCH_PRICE_FIELD  InpStoch_PriceField= StochPrice_LowHigh; // Stoch price
input int                     InpStoch_LevelUp   = 80;        // Stoch Qua mua
input int                     InpStoch_LevelDown = 20;        // Stoch Qua ban

input group "===== INDI MOMENTUM ====="
input int      InpMomentum_Period = 14;      // Momentum Period
input ENUM_APPLIED_PRICE_CUSTOM InpMomentum_Price = Price_Close; // Momentum Price
input double   InpMomentum_LevelUp   = 100.45; // Momentum Qua mua
input double   InpMomentum_LevelDown = 99.45;  // Momentum Qua ban

input group "===== SUPERTREND INDICATOR ====="
input int      InpSupertrend_ATRPeriod  = 21;    // Periods Supertrend
input double   InpSupertrend_Multiplier = 3.0;   // Multiplier Supertrend

input group "===== UTBOT INDICATOR ====="
input int      InpUTBOT_ATRPeriod       = 10;    // Nbr_Periods
input double   InpUTBOT_KeyValue        = 1.0;   // Multiplier
input bool     InpUTBOT_ShowArrows      = true;  // ShowArrows
input int      InpUTBOT_ArrowDist       = 20;    // ArrowDist

input group "===== INDICATOR NGOAI ====="
input string   InpCustomIndicatorName   = "";    // Ten indi
input int      InpCustomIndicatorBuffer = 0;     // Buy buffer
input int      InpCustomIndicatorBuffer2= 1;     // Sell buffer
input int      InpCustomConfirmBars     = 1;     // Nen check tin hieu

input group "===== RSI INDICATOR ====="
input int      InpRSI_Period      = 14;   // RSI Period
input ENUM_APPLIED_PRICE_CUSTOM InpRSI_Price = Price_Close; // Apply price
input int      InpRSI_LevelUp     = 75;   // Qua mua
input int      InpRSI_LevelDown   = 25;   // Qua ban

input group "===== ICHIMOKU INDICATOR ====="
input int      InpIchimoku_Tenkan = 9;    // Tenkan
input int      InpIchimoku_Kijun  = 26;   // Kijun
input int      InpIchimoku_Senkou = 52;   // Senkou

input group "===== BB INDICATOR ====="
input int      InpBB_Period       = 20;    // BB Period
input double   InpBB_Deviation    = 2.0;   // BB Deviations
input ENUM_APPLIED_PRICE_CUSTOM InpBB_Price = Price_Close; // BB Price

input group "===== PINBAR ====="
input double   InpPinbar_WickRatio     = 5.0;  // Ty le rau nen dai so voi than nen
input double   InpPinbar_WickToOppositeRatio = 6.0; // Ty le rau nen dai so voi rau nen ngan
input double   InpPinbar_MinWickPips   = 50.0; // So pips toi thieu cua rau nen dai

input group "===== ENGULFING ====="
input bool     InpEngulfing_FullWickCover = true; // Bao trum toan bo rau nen?
input double   InpEngulfing_MinBodyPips   = 50.0; // So pips toi thieu cua than nen bao trum
input double   InpEngulfing_MinBodyRatio  = 1.1;  // (Nang cao) Ty le Than toi thieu so voi nen truoc

//--- 2.20 CAC NHOM MO RONG (GIU LAI TU BAN CU - KHONG CO TRONG DANH SACH MOI) --------
input group "===== PYRAMIDING SETTINGS ====="
input double   InpPyramidingStepPips      = 150;  // Pyramiding Step (Pips)
input bool     InpPyramidingRequireSignal = true;  // Yeu cau xac nhan tin hieu khi Pyramiding

input group "===== SMART SIGNAL ENGINE SETTINGS ====="
input int      InpSmartFastMA        = 8;    // Smart Internal: EMA nhanh (Period)
input int      InpSmartSlowMA        = 21;   // Smart Internal: EMA cham (Period)
input int      InpSmartTrendMA       = 50;   // Smart Trend: EMA xu huong lon (Period)
input int      InpSmartSwingLookback = 2;    // Smart Swing: So nen 2 ben de xac nhan Fractal

input group "===== VIRTUAL TP/SL MANAGEMENT (AN TP/SL - NANG CAO) ====="
input bool     InpUseVirtualTPSL   = true;   // Enable Virtual TP/SL (Hidden khoi Broker)
input int      InpVirtualCheckMs   = 200;    // Tan suat kiem tra Virtual Management (ms)

input group "===== HEDGING BALANCE MODE (GIUA BUY/SELL - NANG CAO) ====="
input ENUM_LOT_BALANCING InpLotBalancing = Independent_Lots; // Lot Balancing Mode giua Buy/Sell

input group "===== LOT MANAGEMENT (NANG CAO) ====="
input double   InpMaxLotPerOrder = 5.0; // Max Lot per Order (Cap an toan)

input group "===== PARTIAL CLOSURE ENGINE (NANG CAO) ====="
input bool     InpUsePartialClose         = false; // Kich hoat Chot loi mot phan
input double   InpPartialCloseTriggerMoney= 20;    // Muc loi nhuan kich hoat (Tien te tai khoan)
input double   InpPartialClosePercent     = 50;    // Ty le % khoi luong duoc chot
input bool     InpCloseFurthestOrder      = false; // Uu tien cat lenh xa nhat thay vi chot % deu

input group "===== MARTINGALE SL RECOVERY (NANG CAO) ====="
input bool     InpUseSLRecovery          = false; // Kich hoat Martingale SL Recovery
input double   InpSLRecoveryMoney        = 50;    // Muc cat lo kich hoat Recovery (Tien te tai khoan)
input double   InpSLRecoveryLotMultiplier= 2.0;   // He so nhan Lot sau khi SL
input int      InpSLRecoveryDelaySec     = 60;    // Delay truoc khi vao lai sau SL (Giay)
input int      InpSLRecoveryMaxCycles    = 5;     // So chu ky Recovery toi da

input group "===== LOI NHUAN BAC THANG THEO CHUOI (STEP / LADDER PROFIT LOCK - NANG CAO) ====="
// UPGRADE v3.0.6: day chinh la "Trailing theo so tien" (chot loi theo Floating THUC TE
// bang Tien, khong phai Pips) - bat mac dinh de EA tu khoa loi/ve bo theo dung tinh than
// Can Cu Bu Sieng Nang: Loi nhuan dinh (Peak, tinh theo TIEN) duoc "chot tron" theo tung
// bac InpStepProfitStepSize; neu Loi nhuan tut xuong duoi (dinh da chot - Giveback) thi
// EA tu dong dong ca chuoi de KHOA LOI, khong doi "hoi ve" nua roi mat het.
input bool     InpUseStepProfit     = true;  // Kich hoat khoa loi nhuan bac thang theo tung chuoi
input double   InpStepProfitStart   = 20;    // Bat dau khoa khi loi nhuan dat (Money)
input double   InpStepProfitStepSize= 5;     // Buoc nhay moi bac (Money)
input double   InpStepProfitGiveback= 2;     // Cho phep nha loi toi da moi bac (Money)

input group "===== DASHBOARD (HUD) DISPLAY ====="
input bool             InpShowDashboard      = true;              // Hien thi Dashboard
input ENUM_BASE_CORNER InpDashboardCorner    = CORNER_LEFT_UPPER;  // Vi tri goc man hinh
input int              InpDashboardX         = 10;                 // Khoang cach X (px)
input int              InpDashboardY         = 20;                 // Khoang cach Y (px)
input int              InpDashboardFontSize  = 9;                  // Co chu
input color            InpDashboardColorText = clrWhite;           // Mau chu chinh
input color            InpDashboardColorBG   = clrDarkSlateGray;   // Mau nen panel
input color            InpDashboardColorProfit = clrLimeGreen;     // Mau khi lai
input color            InpDashboardColorLoss   = clrTomato;        // Mau khi lo
input bool             InpShowHudButtons     = true;               // Hien thi Nut Bam Tuong Tac (Close Buy/Sell, Reset Lots, Stop Buy/Sell)

//======================================================================
// 3. STRUCT DECLARATIONS
//======================================================================

// --- 3.1 Thong so Symbol da duoc auto-detect (Digits/Pip/Point)
struct SSymbolParams
  {
   int      digits;             // So chu so thap phan cua Symbol
   double   point;               // Gia tri 1 Point
   double   pipSize;             // Gia tri 1 Pip (da quy doi theo Digits: 3/5 so = 10 point)
   int      pipMultiplier;       // He so quy doi Point -> Pip (1 hoac 10)
   double   tickValue;           // Gia tri 1 tick
   double   tickSize;            // Kich thuoc 1 tick
   double   volumeMin;           // Khoi luong toi thieu cho phep
   double   volumeMax;           // Khoi luong toi da cho phep
   double   volumeStep;          // Buoc nhay khoi luong
  };

// --- 3.2 Thong tin 1 lenh trong chuoi Grid/DCA (dung cho Part 2)
struct SGridOrder
  {
   ulong    ticket;              // Ticket cua Position
   int      direction;           // 1 = Buy, -1 = Sell
   double   lot;                 // Khoi luong
   double   openPrice;           // Gia mo lenh
   datetime openTime;            // Thoi gian mo lenh
   double   profit;              // Loi nhuan hien tai cua lenh nay (Profit+Swap, tinh tu lan Sync gan nhat)
   double   virtualSL;           // Gia SL ao (0 = khong dat)
   double   virtualTP;           // Gia TP ao (0 = khong dat)
   bool     virtualActive;       // Co dang quan ly TP/SL ao hay khong
  };

// --- 3.3 Trang thai 1 chuoi lenh (Buy sequence / Sell sequence)
struct SSequenceState
  {
   bool         active;          // Chuoi dang hoat dong
   int          totalOrders;     // Tong so lenh trong chuoi
   double       totalLot;        // Tong khoi luong
   double       avgPrice;        // Gia trung binh
   double       lastOpenPrice;   // Gia mo lenh gan nhat
   datetime     lastOpenTime;    // Thoi gian mo lenh gan nhat
   double       sequenceProfit;  // Loi nhuan hien tai cua chuoi (tien te tai khoan)
   double       peakProfit;      // Loi nhuan dinh (dung cho Step Profit / Partial Close)
   datetime     peakProfitTime;  // Thoi diem gan nhat peakProfit LAP DINH MOI (dung cho Trend Switch - Thoat khi HET DA)
   int          recoveryCycle;   // So chu ky Martingale SL Recovery da chay
   datetime     lastSLTime;      // Thoi diem SL gan nhat (dung cho delay recovery)
   double       trailingStopPrice; // Muc gia Trailing Stop hien tai cua ca chuoi (0 = chua kich hoat)
   int          trimCount;         // So lan da Tia lenh (Advanced Trim) thanh cong
   bool         postTrimActive;    // Dang ap dung TP moi + He so nhan Lot moi SAU khi Tia
   bool         partialTrimMode;   // true neu lan Tia gan nhat la Tia lenh 1 phan (dung them dieu kien Tien/% khi cho Post-Trim TP)
   bool         emergencyActive;   // Dang o che do Dieu chinh TP khi Am (truoc la Emergency TP)
   datetime     lastCloseTime;     // Thoi diem chuoi vua DONG HET gan nhat (dung cho Delay sau khi clear/SL-TP)
   int          lotteryStage;      // Che do Xo So: so lan SL lien tiep (dung nhan He so nhan khi SL)
   bool         manualResetActive; // Nut HUD [Reset Lots]: dang ap dung Lot/He so nhan/TP rieng SAU khi Reset
   SGridOrder   orders[];        // Danh sach lenh trong chuoi
  };

// --- 3.4 Khung gio giao dich (Session)
struct STimeSession
  {
   bool  enabled;                // Session co duoc bat khong
   int   startHour;
   int   startMinute;
   int   endHour;
   int   endMinute;
   bool  valid;                  // Chuoi gio nhap vao co hop le khong
  };

// --- 3.5 Bo nho dem (cache) tin hieu - tinh 1 lan duy nhat cho moi nen moi
//         cua InpSignalTimeframe, tranh goi lai CopyBuffer/CopyRates nhieu lan
//         trong cung 1 nen (toi uu hieu nang khi nhieu tick den lien tuc).
struct SSignalCache
  {
   datetime barTime;             // Thoi gian nen "dang chay" dung lam khoa cache

   bool     cciDone;        int cciBias;
   bool     stochDone;      int stochBias;
   bool     rsiDone;        int rsiBias;
   bool     momDone;        int momBias;
   bool     bbDone;         int bbBias;
   bool     candleDone;     int candleBias;
   bool     randomDone;     int randomBias;
   bool     supertrendDone; int supertrendBias;
   bool     utbotDone;      int utbotBias;
   bool     ichimokuDone;   int ichimokuBias;
   bool     customDone;     int customBias;
   bool     smartTrendDone;    int smartTrendBias;
   bool     smartInternalDone; int smartInternalBias;
   bool     smartSwingDone;    int smartSwingBias;
   bool     pinbarDone;     int pinbarBias;
   bool     engulfingDone;  int engulfingBias;
   bool     macdDone;       int macdBias;    // Bo loc MACD (filter bo sung)
   bool     emaFilterDone;  int emaFilterBias; // Bo loc EMA Trend (filter bo sung)
  };

// --- 3.6 Trang thai lenh Hedge bao ve (Hedging Zone) - toi da 1 lenh Hedge dang mo
struct SHedgeState
  {
   bool     active;
   ulong    ticket;
   int      direction;    // 1 = Buy, -1 = Sell
   double   lot;
   double   openPrice;
   datetime openTime;
  };

// --- 3.6b Trang thai lenh Can bang Khoi luong (Lot Equalizer) - toi da 1 lenh
struct SEqualizerState
  {
   bool   active;
   ulong  ticket;
   int    direction; // 1 = Buy, -1 = Sell
   double lot;
  };

// --- 3.6c Trang thai lenh Mo Nguoc Chieu (Opposite Order) - toi da 1 lenh/chieu
struct SOppositeState
  {
   bool   active;
   ulong  ticket;
   int    direction; // 1 = Buy, -1 = Sell (huong cua LENH NGUOC CHIEU, nguoc voi chuoi goc)
   double lot;
  };

// --- 3.6d Trang thai lenh Hedging Zone (khac voi Hedging thuong o Section 3.6:
//          kich hoat theo SO LENH cua chuoi thay vi %DD, mo lenh bang TONG LOT
//          nhan He so, co Vung gia rieng va TP tong bang Tien/Pips rieng)
struct SHedgeZoneState
  {
   bool   active;
   ulong  ticket;
   int    direction; // 1 = Buy, -1 = Sell
   double lot;
   double openPrice;
  };

// --- 3.7 Muc Virtual SL/TP an noi bo, gan theo Ticket (vi MT5 khong co truong
//         tuy bien tren Position nen phai tu quan ly danh sach song song nay)
struct SVirtualLevel
  {
   ulong  ticket;
   double sl;
   double tp;
  };

//======================================================================
// 4. GLOBAL VARIABLES
//======================================================================
CTrade         trade;                     // Doi tuong giao dich chinh (CTrade)
CSymbolInfo    symbolInfo;                // Thong tin symbol
CPositionInfo  positionInfo;              // Thong tin position

SSymbolParams  g_sym;                     // Thong so Digits/Pip da auto-detect
SSequenceState g_buySeq;                  // Trang thai chuoi Buy
SSequenceState g_sellSeq;                 // Trang thai chuoi Sell
STimeSession   g_sessions[4];             // 4 khung gio giao dich

// --- CHONG TRUOT KHUNG THOI GIAN (Fatal Bug #3): Bien luu CO DINH khung thoi gian
//     cua Chart tai thoi diem EA khoi dong (gan trong OnInit tu _Period). Toan bo logic
//     nen cua DCA (CountOrdersInCurrentBar, nhanh Step_With_BarClose) PHAI dung bien nay
//     THAY VI PERIOD_CURRENT - vi PERIOD_CURRENT luon tra ve khung thoi gian CUA CHART
//     TAI THOI DIEM GOI HAM, neu Nguoi dung chuyen Chart (VD tu M15 sang H1) NGAY TRONG
//     LUC EA dang chay 1 chuoi DCA, toan bo logic Step/Dong nen se bi "truot" sang khung
//     gio moi giua chung, gay sai lech nghiem trong so voi khung gio da dung de tinh cac
//     lenh truoc do trong CUNG 1 chuoi.
ENUM_TIMEFRAMES g_chartTF = PERIOD_CURRENT;

// --- Trend Switch (Section 9.2c): 0 = binh thuong; 1 = BUY dang "duoi" xu huong (nhoi
//     thuan/duong), SELL dang bi DONG BANG (giu nguyen, cho); -1 = nguoc lai (SELL dang
//     duoi, BUY bi dong bang). Chi 1 chieu duoc kich hoat tai 1 thoi diem.
int            g_trendSwitchState = 0;

// --- Trend Switch: "Gia han thoi gian" (Section 9.2c mo rong) - danh dau MOC THOI GIAN
//     (TimeCurrent) ngay tick DAU TIEN 1 chuoi bat dau LIEN TUC thoa dieu kien lo nguong
//     (TrendSwitchLossThresholdMet), de phat hien truong hop thi truong "lu lu" di 1 chieu
//     (drift cham, khong du manh de ADX >= InpTrendSwitchADXEnter) nhung van khien tai khoan
//     am ngay cang sau - neu lien tuc qua InpTrendSwitchGraceMinutes ma ADX van chua manh,
//     BO QUA rieng dieu kien ADX (KHONG bo qua tin hieu dao chieu) de van kich hoat bao ve.
//     Ve 0 khi chuoi tuong ung KHONG con active hoac tam thoi HET lo (duoi nguong).
datetime       g_buyLossSince  = 0;
datetime       g_sellLossSince = 0;

// --- Trend Switch: "Nhoi theo DOT" cho chuoi dang duoi xu huong (Section 9.2c mo rong,
//     xem InpTSPyramidMaxLegs/InpTSPyramidAllowNextBatch/InpTSPyramidBatchPauseMinutes).
//     g_buyBatchStartOrders/g_sellBatchStartOrders = so lenh DA CO trong chuoi tai thoi
//     diem DOT HIEN TAI bat dau (dung de tinh "da nhoi bao nhieu lenh trong DOT nay" =
//     ArraySize(seq.orders) - gia tri nay, LUON theo du lieu that tu broker, khong tu dem
//     tay de tranh lech). g_buyBatchPauseSince/g_sellBatchPauseSince = moc thoi gian DOT
//     hien tai vua day va bat dau NGHI (0 = khong dang nghi). Ve 0 het khi chuoi duoi xu
//     huong ket thuc (Trend Switch huy trang thai) hoac khi 1 DOT moi vua duoc mo.
int            g_buyBatchStartOrders  = 0;
datetime       g_buyBatchPauseSince   = 0;
int            g_sellBatchStartOrders = 0;
datetime       g_sellBatchPauseSince  = 0;

double         g_customLotSeq[];          // Mang Lot da parse tu InpCustomLotSequence
int            g_customLotCount = 0;      // So phan tu hop le trong g_customLotSeq
double         g_customLotSeq2[];         // Mang Lot da parse tu InpCustomLotSequence2 (noi tiep sau chuoi 1)
int            g_customLotCount2 = 0;     // So phan tu hop le trong g_customLotSeq2

datetime       g_lastTickTime   = 0;      // Thoi diem tick gan nhat (dung cho throttle Virtual check)
uint           g_lastVirtualCheckMs = 0;  // Thoi diem check Virtual TP/SL gan nhat (GetTickCount)

const string   HUD_PREFIX = "HUOAI_HUD_"; // Prefix cho toan bo object Dashboard (de xoa sach khi Deinit)

//--- 4.1 Indicator handles (chi tao khi tin hieu tuong ung duoc chon o Input,
//        tranh lang phi tai nguyen/CPU cho cac chi bao khong su dung)
int  h_CCI            = INVALID_HANDLE;
int  h_Stoch          = INVALID_HANDLE;
int  h_RSI            = INVALID_HANDLE;
int  h_Momentum       = INVALID_HANDLE;
int  h_BB             = INVALID_HANDLE;
int  h_ATR_Supertrend = INVALID_HANDLE;
int  h_ATR_UTBOT      = INVALID_HANDLE;
int  h_Ichimoku       = INVALID_HANDLE;
int  h_Custom         = INVALID_HANDLE;
int  h_MA_Fast        = INVALID_HANDLE;   // Smart Internal
int  h_MA_Slow        = INVALID_HANDLE;   // Smart Internal
int  h_MA_Trend       = INVALID_HANDLE;   // Smart Trend
int  h_MACD           = INVALID_HANDLE;   // Bo loc MACD (filter bo sung, khong phai ENUM_SIGNAL_TRIGGER)
int  h_EMA_Filter     = INVALID_HANDLE;   // Bo loc EMA Trend - EMA 1 (filter bo sung / Bo loc trend cho DCA)
int  h_EMA2_Filter    = INVALID_HANDLE;   // Bo loc EMA Trend - EMA 2 (dung cho Min khoang cach EMA1-EMA2)
int  h_RSI_Filter     = INVALID_HANDLE;   // Bo loc RSI (filter bo sung, khong phai ENUM_SIGNAL_TRIGGER)
int  h_ADX_Filter     = INVALID_HANDLE;   // Bo loc ADX cho DCA (UPGRADE v3.0.6, Section 2.4c)
int  h_ATR_DCA        = INVALID_HANDLE;   // ATR dung chung cho "DCA theo ATR" + "Bo loc ATR an toan" (UPGRADE v3.0.6, Section 2.4b/2.4d)

//--- 4.2 Bo nho dem tin hieu (Section 3.5) va cac moc thoi gian "nen moi"
SSignalCache   g_sigCache;
datetime       g_lastStepBarTime  = 0;    // Bar-time gan nhat da DCA (Step_With_Timeframe)
datetime       g_lastChartBarTime = 0;    // Bar-time chart hien tai (Step_With_BarClose / new-bar detector)

//--- 4.3 Trang thai Hedging, Hedging Zone, Lot Equalizer, Mo Nguoc Chieu va
//        danh sach Virtual SL/TP (Section 3.6/3.6b/3.6c/3.6d/3.7)
SHedgeState      g_hedge;         // Hedging (Section 2 G11) - kich hoat theo So lenh / % Drawdown
SHedgeZoneState  g_hedgeZone;     // Hedging Zone (Section 2 G10) - kich hoat theo So lenh, TP tong rieng
SEqualizerState  g_equalizer;
SOppositeState   g_oppBuy;        // Lenh Mo Nguoc Chieu cua chuoi BUY (huong SELL)
SOppositeState   g_oppSell;       // Lenh Mo Nguoc Chieu cua chuoi SELL (huong BUY)
SVirtualLevel    g_vLevels[];
double           g_lastEqualizerOpenTime = 0; // Thoi diem (TimeCurrent) mo lenh Can bang gan nhat (dung cho Delay)

const string   HEDGE_TAG      = " #HEDGE"; // Hau to danh dau lenh Hedge trong Comment (de tach khoi chuoi Buy/Sell)
const string   EQUALIZER_TAG  = " #EQLZ";  // Hau to danh dau lenh Can bang Lot trong Comment
const string   HEDGEZONE_TAG  = " #HEDGEZONE"; // Hau to danh dau lenh Hedging Zone
const string   OPPOSITE_TAG   = " #OPP";       // Hau to danh dau lenh Mo Nguoc Chieu

//--- 4.4 Trang thai Target Loi nhuan Ngay (Daily Profit Target)
datetime       g_dailyDayStamp       = 0;      // Moc 00:00 cua "ngay" dang duoc theo doi (Server Time) - da ap dung Reset
datetime       g_dailyPendingStamp   = 0;      // Moc 00:00 cua ngay MOI vua phat hien, cho InpDailyNewDayDelayMin truoc khi Reset
double         g_dailyStartEquity    = 0.0;    // Equity tai thoi diem bat dau ngay
double         g_dailyStartBalance   = 0.0;    // Balance tai thoi diem bat dau ngay (dung cho Loi nhuan DA CHOT trong ngay)
bool           g_dailyTargetHitToday = false;  // Da dat Target Ngay hay chua (chi de log 1 lan, tranh spam)
bool           g_dailyLossHitToday   = false;  // Da cham Gioi han thua lo Ngay hay chua (chi de log 1 lan, tranh spam)

//--- 4.5 Bang tra cuu Khoang cach Grid da tang (Dynamic Grid Step - Section 2 Module 2)
int            g_gridTierUpTo[];   // Moc so lenh (cumulative) cho tung bac
double         g_gridTierPips[];   // Khoang cach Pips tuong ung moi bac
int            g_gridTierCount = 0;

//--- 4.5b Bang tra cuu He so nhan Lot moi theo moc so lenh (Section 2 G4 - 5 bac)
int            g_lotMultTierUpTo[];  // Moc so lenh (cumulative) cho tung bac He so nhan moi
double         g_lotMultTierValue[]; // He so nhan tuong ung moi bac
int            g_lotMultTierCount = 0;

//--- 4.6 Trang thai cac nut HUD tuong tac (Stop Buy/Sell tam thoi, Reset Lots 1-lan)
//        Cac bien nay CHI TON TAI TRONG BO NHO (khong luu file) - se ve false/off
//        moi khi EA duoc gan lai/compile lai, giong hanh vi nut bam thong thuong.
bool           g_manualStopBuy       = false;  // true = Nguoi dung da bam [Stop Buy] -> tam dung mo lenh Buy moi
bool           g_manualStopSell      = false;  // true = Nguoi dung da bam [Stop Sell] -> tam dung mo lenh Sell moi

//--- 4.6b DEBUG TAM THOI - dung de chan doan ly do EA chua vao lenh. An toan de xoa
//         (cung voi ham PrintEntryDiagnostics() va dong goi no trong OnTick()) sau khi xong.
datetime       g_debugLastBarTime    = 0;
datetime       g_debugLastDCABarTime = 0;   // Tuong tu g_debugLastBarTime nhung danh rieng cho canh bao "DCA bi chan" trong ProcessDCALogic()
bool           g_forceInitialLotBuy  = false;  // true = Lenh Buy TIEP THEO (Entry/DCA) se dung dung InpInitialLot 1 lan
bool           g_forceInitialLotSell = false;  // true = Lenh Sell TIEP THEO (Entry/DCA) se dung dung InpInitialLot 1 lan

//--- 4.7 Theo doi Max Floating Drawdown (tinh tu Equity Peak trong phien EA dang chay)
double         g_peakEquity           = 0.0;   // Dinh Equity cao nhat da ghi nhan tu luc EA khoi dong
double         g_maxFloatingDD_Money  = 0.0;   // Muc Drawdown noi (tu Peak) lon nhat da tung xay ra, tinh bang Tien
double         g_maxFloatingDD_Percent= 0.0;   // Muc Drawdown noi lon nhat, tinh bang % so voi Peak Equity

//--- 4.8 Trang thai Che do Xo So (Lottery / High-Risk Mode)
double         g_lotteryStartEquity  = 0.0;    // Equity tai thoi diem bat dau (hoac EA khoi dong) khi bat Lottery Mode
bool           g_lotteryTargetHit    = false;  // Da dat Target Xo So hay chua (chi xu ly 1 lan)

//--- 4.9 Loi nhuan Bac thang (Staircase Target) - moc "bac" tien do da chot gan nhat
double         g_staircaseLastRung   = 0.0;    // Muc Tien (boi so InpStaircaseTargetMoney) da dong lenh gan nhat
datetime       g_lastStaircaseCloseTime = 0;   // Thoi diem dong lenh Bac thang gan nhat (cho InpStaircaseCloseDelayMin)

//======================================================================
// 5. HAM TIEN ICH / NORMALIZE
//======================================================================

//----------------------------------------------------------------------
// 5.1 Auto-Detect Digits/Pip - tuong thich tai khoan 2,3,4,5 chu so
//----------------------------------------------------------------------
void DetectSymbolParams()
  {
   g_sym.digits      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_sym.point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_sym.tickValue   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_sym.tickSize    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_sym.volumeMin   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_sym.volumeMax   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_sym.volumeStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // --- Nhan dien rieng Kim loai (Vang/Bac): quy uoc pip CHUAN cua thi truong cho
   //     Vang la 1 Pip = 0.1 (VD gia XAUUSD 2650.45 -> 2650.55 la 1 pip), BAT KE san
   //     bao gia bang 2 hay 3 chu so thap phan, va BAT KE tai khoan la USD hay Cent -
   //     vi Digits/Point cua symbol duoc doc TRUC TIEP tu chinh san moi lan EA khoi
   //     dong (khong hard-code), nen tu dong tuong thich moi loai tai khoan/broker.
   //     Quy tac Forex thong thuong (digits 3/5 -> x10) KHONG dung cho Vang vi da so
   //     san bao gia Vang chi 2 hoac 3 chu so nhung deu quy uoc pip = 0.1 nhu nhau.
   string symUpper = _Symbol;
   StringToUpper(symUpper);
   bool isMetal = (StringFind(symUpper, "XAU") >= 0 || StringFind(symUpper, "GOLD") >= 0);

   if(isMetal)
     {
      // Neu Point cua san >= 0.1 (VD san chi bao gia nguyen $ hoac 1 le), khong the
      // chia nho hon Point -> dung luon Point de tranh PipSize < Tick that vo ly.
      g_sym.pipSize       = (g_sym.point < 0.1) ? 0.1 : g_sym.point;
      g_sym.pipMultiplier = (g_sym.point > 0.0) ? (int)MathRound(g_sym.pipSize / g_sym.point) : 1;
     }
   else
     {
      // Tai khoan 3 hoac 5 chu so thap phan (JPY-pairs 3, Forex thuong 5)
      // => 1 Pip = 10 Point. Tai khoan 2 hoac 4 chu so => 1 Pip = 1 Point.
      if(g_sym.digits == 3 || g_sym.digits == 5)
         g_sym.pipMultiplier = 10;
      else
         g_sym.pipMultiplier = 1;

      g_sym.pipSize = g_sym.point * g_sym.pipMultiplier;
     }
  }

//----------------------------------------------------------------------
// 5.2 Quy doi Pips <-> Gia (Price distance)
//----------------------------------------------------------------------
double PipsToPrice(const double pips)
  {
   return(pips * g_sym.pipSize);
  }

double PriceToPips(const double priceDistance)
  {
   if(g_sym.pipSize <= 0.0)
      return(0.0);
   return(priceDistance / g_sym.pipSize);
  }

//----------------------------------------------------------------------
// 5.3 Normalize Gia theo Digits cua Symbol
//----------------------------------------------------------------------
double NormalizePriceValue(const double price)
  {
   return(NormalizeDouble(price, g_sym.digits));
  }

//----------------------------------------------------------------------
// 5.4 Normalize Lot theo VolumeStep/Min/Max cua Symbol (kem Max Cap input)
//----------------------------------------------------------------------
double NormalizeLotValue(double lot)
  {
   if(g_sym.volumeStep <= 0.0)
      g_sym.volumeStep = 0.01;

   double steps = MathRound(lot / g_sym.volumeStep);
   double normalized = steps * g_sym.volumeStep;

   if(InpMaxLotPerOrder > 0.0 && normalized > InpMaxLotPerOrder)
      normalized = InpMaxLotPerOrder;

   if(normalized < g_sym.volumeMin)
      normalized = g_sym.volumeMin;
   if(g_sym.volumeMax > 0.0 && normalized > g_sym.volumeMax)
      normalized = g_sym.volumeMax;

   int lotDigits = 2;
   if(g_sym.volumeStep < 0.01)
      lotDigits = 3;
   if(g_sym.volumeStep < 0.001)
      lotDigits = 4;

   return(NormalizeDouble(normalized, lotDigits));
  }

//----------------------------------------------------------------------
// 5.4b BOI LENH THU CONG & KET HOP MAGIC NUMBER - 1 Position (cung Symbol)
//      duoc EA coi la "cua minh" (dua vao Sync/Dong lenh/Virtual TP-SL) khi:
//        - Magic Number khop InpMagicNumber (lenh do chinh EA mo), HOAC
//        - InpAllowManualOrders=true VA Magic Number cua Position = 0 (lenh
//          nguoi dung bam tay tren Chart, MT5 mac dinh gan Magic=0 cho lenh do).
//----------------------------------------------------------------------
bool IsManagedPosition(const long posMagic, const string posComment = "")
  {
   // Magic Number = 0 -> EA chuyen sang che do "Thu cong toan bo": quan ly TAT CA
   // Position tren Symbol nay, bat ke Magic/Comment (dung khi nguoi dung muon EA
   // ho tro quan ly toan bo lenh tay tren 1 chart).
   if(InpMagicNumber == 0) return(true);

   if(posMagic == InpMagicNumber)
     {
      // Ket hop EA cung Magic = true -> chi can trung Magic la du (gop ca cac lenh
      // cua ban sao EA khac / chart khac dung chung Magic). = false -> BAT BUOC
      // Comment cung phai bat dau bang InpOrderComment (tach rieng tung ban sao EA).
      if(InpCombineSameMagic) return(true);
      if(posComment == "" || StringFind(posComment, InpOrderComment) == 0) return(true);
      return(false);
     }

   if(InpAllowManualOrders && posMagic == 0) return(true);
   return(false);
  }

//----------------------------------------------------------------------
// 5.5 Parse chuoi Custom Lot Sequence dang "0.01-0.02-0.03..."
//----------------------------------------------------------------------
bool ParseCustomLotSequence(const string seq, double &outArr[], int &outCount)
  {
   ArrayFree(outArr);
   outCount = 0;

   string parts[];
   int total = StringSplit(seq, '-', parts);
   if(total <= 0)
      return(false);

   ArrayResize(outArr, total);
   int validCount = 0;
   for(int i = 0; i < total; i++)
     {
      string token = parts[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      if(token == "")
         continue;

      double val = StringToDouble(token);
      if(val <= 0.0)
        {
         PrintFormat("[Huuoaifx DCA] Canh bao: gia tri Lot khong hop le trong Custom Lot Sequence: '%s'", token);
         continue;
        }
      outArr[validCount] = val;
      validCount++;
     }

   ArrayResize(outArr, validCount);
   outCount = validCount;
   return(validCount > 0);
  }

//----------------------------------------------------------------------
// 5.5b Parse chuoi Khoang cach Grid da tang dang "MocLenh:Pips,MocLenh:Pips,..."
//      Vi du "5:30,10:40,15:50,999:60" nghia la: lenh thu 1-5 cach 30 pips,
//      lenh thu 6-10 cach 40 pips, lenh thu 11-15 cach 50 pips, tu lenh 16
//      tro di dung 60 pips (moc cuoi cung duoc dung lam "tran" mac dinh).
//----------------------------------------------------------------------
bool ParseDynamicGridSteps(const string s, int &tierUpTo[], double &tierPips[], int &count)
  {
   ArrayFree(tierUpTo); ArrayFree(tierPips);
   count = 0;

   string groups[];
   int total = StringSplit(s, ',', groups);
   if(total <= 0) return(false);

   ArrayResize(tierUpTo, total);
   ArrayResize(tierPips, total);
   int n = 0;

   for(int i = 0; i < total; i++)
     {
      string g = groups[i];
      StringTrimLeft(g); StringTrimRight(g);
      if(g == "") continue;

      string parts[];
      int pcount = StringSplit(g, ':', parts);
      if(pcount != 2) continue;

      int    upTo = (int)StringToInteger(parts[0]);
      double pips = StringToDouble(parts[1]);
      if(upTo <= 0 || pips <= 0.0) continue;

      tierUpTo[n] = upTo; tierPips[n] = pips; n++;
     }

   ArrayResize(tierUpTo, n);
   ArrayResize(tierPips, n);
   count = n;
   return(n > 0);
  }

// Tra ve Khoang cach (Pips) ap dung cho lenh thu (orderIndex+1) trong chuoi,
// dua theo bang g_gridTierUpTo/g_gridTierPips. Neu InpUseDynamicGridStep tat
// hoac chua parse duoc bang nao hop le -> fallback ve InpFixedStepPips.
double GetDCAStepPips(const int orderIndex)
  {
   if(!InpUseDynamicGridStep || g_gridTierCount <= 0)
      return(InpFixedStepPips);

   int orderNumber = orderIndex + 1;
   for(int i = 0; i < g_gridTierCount; i++)
      if(orderNumber <= g_gridTierUpTo[i])
         return(g_gridTierPips[i]);

   return(g_gridTierPips[g_gridTierCount - 1]); // Vuot tat ca moc -> dung Pips cua moc cuoi
  }

//----------------------------------------------------------------------
// 5.6 Parse chuoi gio "HH:MM" -> hour/minute, kiem tra hop le
//----------------------------------------------------------------------
bool ParseTimeString(const string hhmm, int &hourOut, int &minuteOut)
  {
   string parts[];
   int total = StringSplit(hhmm, ':', parts);
   if(total != 2)
      return(false);

   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);

   if(h < 0 || h > 23 || m < 0 || m > 59)
      return(false);

   hourOut   = h;
   minuteOut = m;
   return(true);
  }

//----------------------------------------------------------------------
// 5.7 Khoi tao 4 Session gio giao dich tu Input string
//----------------------------------------------------------------------
void InitSessions()
  {
   bool enables[4];
   string starts[4];
   string ends[4];

   enables[0] = InpSession1_Enable; starts[0] = InpSession1_Start; ends[0] = InpSession1_End;
   enables[1] = InpSession2_Enable; starts[1] = InpSession2_Start; ends[1] = InpSession2_End;
   enables[2] = InpSession3_Enable; starts[2] = InpSession3_Start; ends[2] = InpSession3_End;
   enables[3] = InpSession4_Enable; starts[3] = InpSession4_Start; ends[3] = InpSession4_End;

   for(int i = 0; i < 4; i++)
     {
      g_sessions[i].enabled = enables[i];

      int sh = 0, sm = 0, eh = 0, em = 0;
      bool okStart = ParseTimeString(starts[i], sh, sm);
      bool okEnd   = ParseTimeString(ends[i], eh, em);

      g_sessions[i].valid = (okStart && okEnd);
      if(g_sessions[i].valid)
        {
         g_sessions[i].startHour   = sh;
         g_sessions[i].startMinute = sm;
         g_sessions[i].endHour     = eh;
         g_sessions[i].endMinute   = em;
        }
      else
        {
         g_sessions[i].startHour   = 0;
         g_sessions[i].startMinute = 0;
         g_sessions[i].endHour     = 0;
         g_sessions[i].endMinute   = 0;
         if(enables[i])
            PrintFormat("[Huuoaifx DCA] Canh bao: Session %d co dinh dang gio khong hop le (%s - %s), da bi vo hieu hoa.",
                        i + 1, starts[i], ends[i]);
        }
     }
  }

//----------------------------------------------------------------------
// 5.8 Reset trang thai 1 chuoi lenh (SSequenceState) ve mac dinh
//----------------------------------------------------------------------
void ResetSequenceState(SSequenceState &seq)
  {
   seq.active         = false;
   seq.totalOrders    = 0;
   seq.totalLot       = 0.0;
   seq.avgPrice       = 0.0;
   seq.lastOpenPrice  = 0.0;
   seq.lastOpenTime   = 0;
   seq.sequenceProfit = 0.0;
   seq.peakProfit     = 0.0;
   seq.peakProfitTime = 0;
   seq.recoveryCycle  = 0;
   seq.lastSLTime     = 0;
   seq.trailingStopPrice = 0.0;
   seq.trimCount          = 0;
   seq.postTrimActive     = false;
   seq.partialTrimMode    = false;
   seq.emergencyActive    = false;
   seq.lastCloseTime      = 0;
   seq.lotteryStage       = 0;
   seq.manualResetActive  = false;
   ArrayFree(seq.orders);
  }

//----------------------------------------------------------------------
// 5.9 Kiem tra tinh hop le cua bo Input (Validation truoc khi chay EA)
//----------------------------------------------------------------------
bool ValidateInputs()
  {
   bool ok = true;

   if(InpInitialLot <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: InpInitialLot phai > 0.");
      ok = false;
     }

   if(InpMaxDCAOrders <= 0)
     {
      Print("[Huuoaifx DCA] Loi: So lenh buy toi da (InpMaxDCAOrders) phai > 0.");
      ok = false;
     }
   if(InpMaxSellOrders <= 0)
     {
      Print("[Huuoaifx DCA] Loi: So lenh sell toi da (InpMaxSellOrders) phai > 0.");
      ok = false;
     }

   if(InpLotMode == Custom_Lot_Sequence)
     {
      if(!ParseCustomLotSequence(InpCustomLotSequence, g_customLotSeq, g_customLotCount))
        {
         Print("[Huuoaifx DCA] Loi: 1.He so thu cong (InpCustomLotSequence) khong hop le hoac rong. Vi du dung: \"0.01-0.02-0.03\"");
         ok = false;
        }
      if(InpCustomLotSequence2 != "")
        {
         if(!ParseCustomLotSequence(InpCustomLotSequence2, g_customLotSeq2, g_customLotCount2))
            Print("[Huuoaifx DCA] Canh bao: 2.He so thu cong (InpCustomLotSequence2) khong hop le - se KHONG dung chuoi noi tiep nay.");
        }
     }

   if(InpDCAMethod == Fixed_Step && InpFixedStepPips <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: 0.Khoang cach nhoi lenh ban dau (InpFixedStepPips) phai > 0 khi dung Fixed_Step.");
      ok = false;
     }

   if(InpUseMACDFilter)
     {
      if(InpMACD_FastEMA <= 0 || InpMACD_SlowEMA <= 0 || InpMACD_SMA <= 0)
        {
         Print("[Huuoaifx DCA] Loi: InpMACD_FastEMA/InpMACD_SlowEMA/InpMACD_SMA phai > 0 khi dung Bo loc MACD.");
         ok = false;
        }
      else if(InpMACD_FastEMA >= InpMACD_SlowEMA)
        {
         Print("[Huuoaifx DCA] Loi: InpMACD_FastEMA phai NHO HON InpMACD_SlowEMA.");
         ok = false;
        }
     }

   // --- UPGRADE v3.0.6: kiem tra hop le cho cac Bo loc/Tinh nang moi (Section 2.4b-2.4f)
   if((InpDCA_UseATRDistance || InpUseATRFilter) && InpDCA_ATR_Period <= 0)
     {
      Print("[Huuoaifx DCA] Loi: InpDCA_ATR_Period phai > 0 khi dung DCA theo ATR hoac Bo loc ATR.");
      ok = false;
     }
   if((InpUseADXFilter || InpUseTrendSwitch) && InpADX_Period <= 0)
     {
      Print("[Huuoaifx DCA] Loi: InpADX_Period phai > 0 khi dung Bo loc ADX hoac Trend Switch.");
      ok = false;
     }
   if(InpUseATRFilter && InpATR_MinPips > 0.0 && InpATR_MaxPips > 0.0 && InpATR_MinPips >= InpATR_MaxPips)
     {
      Print("[Huuoaifx DCA] Loi: InpATR_MinPips phai NHO HON InpATR_MaxPips (Bo loc ATR an toan).");
      ok = false;
     }
   if(InpUseNewsFilter && (InpNewsMinutesBefore < 0 || InpNewsMinutesAfter < 0))
     {
      Print("[Huuoaifx DCA] Loi: InpNewsMinutesBefore/InpNewsMinutesAfter khong duoc am.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpTradeExecution != Buy_And_Sell)
     {
      Print("[Huuoaifx DCA] Loi: Trend Switch (InpUseTrendSwitch) can InpTradeExecution = Buy_And_Sell de co the giu nguyen 1 chieu dang lo VA mo/nhoi chieu con lai doc lap cung luc.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpCloseOnTrendReversal)
     {
      Print("[Huuoaifx DCA] Loi: Khong nen bat dong thoi InpUseTrendSwitch va InpCloseOnTrendReversal - 2 co che xu ly dao chieu xung khac nhau (1 ben dong bang+cho trung binh gia, 1 ben dong toan bo chuoi lo ngay lap tuc). Chi chon 1 trong 2.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpTrendSwitchMinLossPips < 0.0)
     {
      Print("[Huuoaifx DCA] Loi: InpTrendSwitchMinLossPips khong duoc am.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpTrendSwitchTriggerMode == TS_Trigger_PercentAccount && InpTrendSwitchPercent <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: InpTrendSwitchPercent phai > 0 khi chon Kieu nguong 1 (% Tai khoan) cho Trend Switch.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpTrendSwitchTriggerMode == TS_Trigger_Money && InpTrendSwitchMoneyLoss <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: InpTrendSwitchMoneyLoss phai > 0 khi chon Kieu nguong 3 (So tien cu the) cho Trend Switch.");
      ok = false;
     }
   if(InpUseTrendSwitch && InpTrendSwitchTriggerMode == TS_Trigger_Pips && InpTrendSwitchMinLossPips <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: InpTrendSwitchMinLossPips phai > 0 khi chon Kieu nguong 2 (Pip cua chuoi) cho Trend Switch.");
      ok = false;
     }

   if(InpUseEMAFilter && (InpEMA_Period <= 0 || InpEMA2_Period <= 0))
     {
      Print("[Huuoaifx DCA] Loi: EMA 1 / EMA 2 (InpEMA_Period/InpEMA2_Period) phai > 0 khi dung Bo loc EMA.");
      ok = false;
     }

   if(InpUseDCATrendFilter && InpEMA_Period <= 0)
     {
      Print("[Huuoaifx DCA] Loi: EMA 1 (InpEMA_Period) phai > 0 khi dung Bo loc trend cho DCA.");
      ok = false;
     }

   if(InpUseRSIFilter && InpRSIFilter_Period <= 0)
     {
      Print("[Huuoaifx DCA] Loi: RSI Period (InpRSIFilter_Period) cua Bo loc RSI phai > 0.");
      ok = false;
     }

   if(InpUseZoneCycle && InpZoneCyclePriceUpper <= InpZoneCyclePriceLower)
     {
      Print("[Huuoaifx DCA] Loi: Vung gia tren (InpZoneCyclePriceUpper) phai LON HON Vung gia duoi (InpZoneCyclePriceLower) khi dung Zone Cycle.");
      ok = false;
     }

   if(InpMaxSpreadPips < 0.0)
     {
      Print("[Huuoaifx DCA] Loi: Spread toi da (InpMaxSpreadPips) khong duoc am (0 = Khong gioi han).");
      ok = false;
     }

   if(InpMaxTotalLot < 0.0)
     {
      Print("[Huuoaifx DCA] Loi: Lots toi da (InpMaxTotalLot) khong duoc am (0 = Khong gioi han).");
      ok = false;
     }

   if(InpEnableLotteryMode && InpLotteryTargetMultiplier != 0.0 && InpLotteryTargetMultiplier <= 1.0)
     {
      Print("[Huuoaifx DCA] Loi: Target Multiplier (InpLotteryTargetMultiplier) phai > 1.0 hoac = 0 (Tat) khi bat Che do Xo So.");
      ok = false;
     }

   if(InpUsePartialClose && (InpPartialClosePercent <= 0.0 || InpPartialClosePercent > 100.0))
     {
      Print("[Huuoaifx DCA] Loi: InpPartialClosePercent phai trong khoang (0, 100].");
      ok = false;
     }

   if(InpUseHedging && InpHedgeActivateCount <= 0 && InpHedgePercent == 0.0 && InpHedgeZoneTriggerPercent <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: Khi bat Hedging, phai bat it nhat 1 dieu kien kich hoat (So lenh kich hoat hedging, "+
            "Phan tram kich hoat hedging, hoac Nguong % Drawdown nang cao).");
      ok = false;
     }

   if(InpUseHedgingZone && InpHedgeZoneActivateCount <= 0)
     {
      Print("[Huuoaifx DCA] Loi: So lenh kich hoat Hedging Zone (InpHedgeZoneActivateCount) phai > 0 khi dung Hedging Zone.");
      ok = false;
     }

   if(InpUseOppositeOrder && InpOppositeActivateCount <= 0)
     {
      Print("[Huuoaifx DCA] Loi: So lenh kich hoat mo lenh nguoc chieu (InpOppositeActivateCount) phai > 0.");
      ok = false;
     }

   if(InpUseStaircaseTarget && InpStaircaseTargetMoney <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: So tien Muc tieu loi nhuan bac thang (InpStaircaseTargetMoney) phai > 0.");
      ok = false;
     }

   // --- Xay bang tier Khoang cach Grid da tang: uu tien InpDynamicGridSteps (chuoi
   //     nang cao) neu duoc dien, nguoc lai tu dong ghep tu 4 cap Tier ben tren.
   if(InpUseDynamicGridStep)
     {
      if(InpDynamicGridSteps != "")
        {
         if(!ParseDynamicGridSteps(InpDynamicGridSteps, g_gridTierUpTo, g_gridTierPips, g_gridTierCount))
           {
            Print("[Huuoaifx DCA] Loi: InpDynamicGridSteps khong hop le. Vi du dung: \"5:30,10:40,15:50,999:60\" (hoac de trong de dung 4 Tier ben tren).");
            ok = false;
           }
        }
      else
        {
         int    upTo[]; double pips[]; int n = 0;
         ArrayResize(upTo, 4); ArrayResize(pips, 4);
         if(InpGridStepTier1Count > 0 && InpGridStepTier1Pips > 0.0) { upTo[n] = InpGridStepTier1Count; pips[n] = InpGridStepTier1Pips; n++; }
         if(InpGridStepTier2Count > 0 && InpGridStepTier2Pips > 0.0) { upTo[n] = InpGridStepTier2Count; pips[n] = InpGridStepTier2Pips; n++; }
         if(InpGridStepTier3Count > 0 && InpGridStepTier3Pips > 0.0) { upTo[n] = InpGridStepTier3Count; pips[n] = InpGridStepTier3Pips; n++; }
         if(InpGridStepTier4Count > 0 && InpGridStepTier4Pips > 0.0) { upTo[n] = InpGridStepTier4Count; pips[n] = InpGridStepTier4Pips; n++; }
         ArrayResize(upTo, n); ArrayResize(pips, n);
         ArrayFree(g_gridTierUpTo); ArrayFree(g_gridTierPips);
         ArrayResize(g_gridTierUpTo, n); ArrayResize(g_gridTierPips, n);
         for(int i = 0; i < n; i++) { g_gridTierUpTo[i] = upTo[i]; g_gridTierPips[i] = pips[i]; }
         g_gridTierCount = n;
         if(g_gridTierCount <= 0)
           {
            Print("[Huuoaifx DCA] Loi: Khong co Tier Khoang cach Grid nao hop le (1-4.So lenh tang khoang cach / Khoang cach nhoi lenh).");
            ok = false;
           }
        }
     }

   // --- Xay bang tier He so nhan Lot moi (5 bac) khi InpUseLotMultiplierTiers=true
   if(InpUseLotMultiplierTiers)
     {
      int    mUpTo[]; double mVal[]; int mn = 0;
      ArrayResize(mUpTo, 5); ArrayResize(mVal, 5);
      if(InpLotMultTier1Count > 0 && InpLotMultTier1Value > 0.0) { mUpTo[mn] = InpLotMultTier1Count; mVal[mn] = InpLotMultTier1Value; mn++; }
      if(InpLotMultTier2Count > 0 && InpLotMultTier2Value > 0.0) { mUpTo[mn] = InpLotMultTier2Count; mVal[mn] = InpLotMultTier2Value; mn++; }
      if(InpLotMultTier3Count > 0 && InpLotMultTier3Value > 0.0) { mUpTo[mn] = InpLotMultTier3Count; mVal[mn] = InpLotMultTier3Value; mn++; }
      if(InpLotMultTier4Count > 0 && InpLotMultTier4Value > 0.0) { mUpTo[mn] = InpLotMultTier4Count; mVal[mn] = InpLotMultTier4Value; mn++; }
      if(InpLotMultTier5Count > 0 && InpLotMultTier5Value > 0.0) { mUpTo[mn] = InpLotMultTier5Count; mVal[mn] = InpLotMultTier5Value; mn++; }
      ArrayResize(mUpTo, mn); ArrayResize(mVal, mn);
      ArrayFree(g_lotMultTierUpTo); ArrayFree(g_lotMultTierValue);
      ArrayResize(g_lotMultTierUpTo, mn); ArrayResize(g_lotMultTierValue, mn);
      for(int i = 0; i < mn; i++) { g_lotMultTierUpTo[i] = mUpTo[i]; g_lotMultTierValue[i] = mVal[i]; }
      g_lotMultTierCount = mn;
      if(g_lotMultTierCount <= 0)
        {
         Print("[Huuoaifx DCA] Loi: Khong co Tier He so nhan Lot moi nao hop le (1-5.So lenh kich hoat / He so nhan moi).");
         ok = false;
        }
     }

   if(InpUseAdvancedTrim && InpMinOrdersToTrim < 2)
     {
      Print("[Huuoaifx DCA] Loi: So lenh kich hoat tia lan dau (InpMinOrdersToTrim) phai >= 2 khi dung Tia lenh.");
      ok = false;
     }

   if(InpUseAdvancedTrim && !InpTrimUseNewestProfit && (InpTrimClosePercent <= 0.0 || InpTrimClosePercent > 100.0))
     {
      Print("[Huuoaifx DCA] Loi: InpTrimClosePercent phai trong khoang (0, 100] khi InpTrimUseNewestProfit=false.");
      ok = false;
     }

   if(InpUseLotEqualizer)
     {
      if(InpLotDiffStop >= InpLotDiffTrigger)
        {
         Print("[Huuoaifx DCA] Loi: So lots chenh lech dung can lots (InpLotDiffStop) phai NHO HON So lots chenh lech kich hoat (InpLotDiffTrigger).");
         ok = false;
        }
      if(InpBalancingLot < g_sym.volumeMin)
        {
         Print("[Huuoaifx DCA] Loi: Lots mo them (InpBalancingLot) phai >= Volume Min cua Symbol.");
         ok = false;
        }
     }

   if(g_sym.volumeMin <= 0.0)
     {
      Print("[Huuoaifx DCA] Loi: Khong lay duoc thong tin Volume Min tu Symbol. Kiem tra lai ket noi.");
      ok = false;
     }

   return(ok);
  }

//----------------------------------------------------------------------
// 5.10 In log tom tat cau hinh khi khoi dong (khong hien thi ban quyen thua tren HUD)
//----------------------------------------------------------------------
void PrintStartupSummary()
  {
   PrintFormat("[Huuoaifx DCA] ==== KHOI DONG EA ====");
   PrintFormat("[Huuoaifx DCA] Symbol=%s | Digits=%d | PipSize=%.*f (x%d Point) | Comment='%s'",
               _Symbol, g_sym.digits, g_sym.digits, g_sym.pipSize, g_sym.pipMultiplier, InpOrderComment);
   PrintFormat("[Huuoaifx DCA] TradeExecution=%s | DCAMethod=%s | LotMode=%s | LotBalancing=%s",
               EnumToString(InpTradeExecution), EnumToString(InpDCAMethod),
               EnumToString(InpLotMode), EnumToString(InpLotBalancing));
   PrintFormat("[Huuoaifx DCA] VirtualTPSL=%s (SL=%.1f pips / TP=%.1f pips) | SLRecovery=%s | PartialClose=%s | Hedging=%s",
               (InpUseVirtualTPSL ? "ON" : "OFF"), InpVirtualSL_Pips, InpVirtualTP_Pips,
               (InpUseSLRecovery ? "ON" : "OFF"), (InpUsePartialClose ? "ON" : "OFF"),
               (InpUseHedging ? "ON" : "OFF"));
   if(InpLotMode == Custom_Lot_Sequence)
      PrintFormat("[Huuoaifx DCA] Custom Lot Sequence: %d gia tri hop le da duoc parse.", g_customLotCount);
   PrintFormat("[Huuoaifx DCA] ==========================");
  }

//----------------------------------------------------------------------
// 5.11 Chuyen doi ENUM tuy bien -> ENUM chuan cua MQL5 (dung khi tao handle)
//----------------------------------------------------------------------
ENUM_APPLIED_PRICE ToStdAppliedPrice(const ENUM_APPLIED_PRICE_CUSTOM p)
  {
   switch(p)
     {
      case Price_Close:    return(PRICE_CLOSE);
      case Price_Open:     return(PRICE_OPEN);
      case Price_High:     return(PRICE_HIGH);
      case Price_Low:      return(PRICE_LOW);
      case Price_Median:   return(PRICE_MEDIAN);
      case Price_Typical:  return(PRICE_TYPICAL);
      case Price_Weighted: return(PRICE_WEIGHTED);
     }
   return(PRICE_CLOSE);
  }

ENUM_MA_METHOD ToStdMAMethod(const ENUM_STOCH_MA_METHOD m)
  {
   switch(m)
     {
      case Mode_SMA:  return(MODE_SMA);
      case Mode_EMA:  return(MODE_EMA);
      case Mode_SMMA: return(MODE_SMMA);
      case Mode_LWMA: return(MODE_LWMA);
     }
   return(MODE_SMA);
  }

//----------------------------------------------------------------------
// 5.12 Xac dinh 1 loai tin hieu co dang duoc su dung (Entry hoac DCA) khong
//      -> chi tao Indicator Handle khi that su can, tiet kiem tai nguyen.
//----------------------------------------------------------------------
bool SignalInUse(const ENUM_SIGNAL_TRIGGER a, const ENUM_SIGNAL_TRIGGER b)
  {
   return(InpEntrySignal == a || InpEntrySignal == b || InpDCASignal == a || InpDCASignal == b);
  }

bool SignalInUse(const ENUM_SIGNAL_TRIGGER a)
  {
   return(InpEntrySignal == a || InpDCASignal == a);
  }

//----------------------------------------------------------------------
// 5.13 Tao toan bo Indicator Handle can thiet cho Signal Engine (Phan 2)
//----------------------------------------------------------------------
bool CreateIndicatorHandles()
  {
   bool allOk = true;
   // Smart Signal Engine (MA Fast/Slow/Trend) khong co Input Applied Price rieng trong ban
   // sap xep moi -> dung mac dinh PRICE_CLOSE (gia Dong cua) cho cac EMA noi bo nay.
   ENUM_APPLIED_PRICE stdPrice = PRICE_CLOSE;

   if(SignalInUse(CCI, CCI_Reverse))
     {
      h_CCI = iCCI(_Symbol, InpSignalTimeframe, InpCCI_Period, ToStdAppliedPrice(InpCCI_Price));
      if(h_CCI == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iCCI."); allOk = false; }
     }

   if(SignalInUse(Stochastic, Stoch_Reverse))
     {
      ENUM_STO_PRICE stochPriceField = (InpStoch_PriceField == StochPrice_CloseClose) ? STO_CLOSECLOSE : STO_LOWHIGH;
      h_Stoch = iStochastic(_Symbol, InpSignalTimeframe, InpStoch_K, InpStoch_D, InpStoch_Slowing,
                             ToStdMAMethod(InpStoch_MAMethod), stochPriceField);
      if(h_Stoch == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iStochastic."); allOk = false; }
     }

   if(SignalInUse(RSI, RSI_Reverse))
     {
      h_RSI = iRSI(_Symbol, InpSignalTimeframe, InpRSI_Period, ToStdAppliedPrice(InpRSI_Price));
      if(h_RSI == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iRSI."); allOk = false; }
     }

   // --- Bo loc RSI (doc lap voi ENUM_SIGNAL_TRIGGER RSI o tren - AND-gate bo sung,
   //     dung bo tham so rieng InpRSIFilter_* de khong xung dot voi RSI lam tin hieu chinh)
   if(InpUseRSIFilter)
     {
      h_RSI_Filter = iRSI(_Symbol, InpRSIFilter_TF, InpRSIFilter_Period, ToStdAppliedPrice(InpRSIFilter_Price));
      if(h_RSI_Filter == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iRSI (Bo loc RSI)."); allOk = false; }
     }

   if(SignalInUse(Momentum))
     {
      h_Momentum = iMomentum(_Symbol, InpSignalTimeframe, InpMomentum_Period, ToStdAppliedPrice(InpMomentum_Price));
      if(h_Momentum == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iMomentum."); allOk = false; }
     }

   if(SignalInUse(Bollinger_Bands))
     {
      h_BB = iBands(_Symbol, InpSignalTimeframe, InpBB_Period, 0, InpBB_Deviation, ToStdAppliedPrice(InpBB_Price));
      if(h_BB == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iBands."); allOk = false; }
     }

   // --- Bo loc MACD (doc lap voi ENUM_SIGNAL_TRIGGER - la lop AND-gate bo sung
   //     ben trong IsSignalConfirmed(), khong phai 1 lua chon tin hieu chinh).
   if(InpUseMACDFilter)
     {
      h_MACD = iMACD(_Symbol, InpMACD_Timeframe, InpMACD_FastEMA, InpMACD_SlowEMA, InpMACD_SMA, ToStdAppliedPrice(InpMACD_Price));
      if(h_MACD == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iMACD."); allOk = false; }
     }

   // --- Bo loc EMA Trend (EMA1/EMA2) - dung cho ca "Bo loc EMA" (AND-gate Section 2.18)
   //     VA "Bo loc trend cho DCA" (Section 2.4) - 2 tinh nang doc lap dung chung 1 cap Handle.
   if(InpUseEMAFilter || InpUseDCATrendFilter)
     {
      h_EMA_Filter = iMA(_Symbol, InpEMA_Timeframe, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(h_EMA_Filter == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iMA (EMA Filter)."); allOk = false; }
     }
   if(InpUseEMAFilter)
     {
      h_EMA2_Filter = iMA(_Symbol, InpEMA_Timeframe, InpEMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(h_EMA2_Filter == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iMA (EMA2 Filter)."); allOk = false; }
     }

   if(SignalInUse(Supertrend))
     {
      h_ATR_Supertrend = iATR(_Symbol, InpSignalTimeframe, InpSupertrend_ATRPeriod);
      if(h_ATR_Supertrend == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iATR (Supertrend)."); allOk = false; }
     }

   if(SignalInUse(UTBOT_Signal))
     {
      h_ATR_UTBOT = iATR(_Symbol, InpSignalTimeframe, InpUTBOT_ATRPeriod);
      if(h_ATR_UTBOT == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iATR (UTBOT)."); allOk = false; }
     }

   // --- UPGRADE v3.0.6: Bo loc ADX cho DCA (Section 2.4c) - dung chung handle nay cho ca
   //     Trend Switch (Section 9.2c, InpUseTrendSwitch dung do do manh xu huong ADX de
   //     kich hoat/huy) de khong phai tao them 1 handle iADX trung lap.
   if(InpUseADXFilter || InpUseTrendSwitch)
     {
      h_ADX_Filter = iADX(_Symbol, InpADX_Timeframe, InpADX_Period);
      if(h_ADX_Filter == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iADX (Bo loc ADX / Trend Switch)."); allOk = false; }
     }

   // --- UPGRADE v3.0.6: ATR dung chung cho "DCA theo ATR" (Step + Dong nen) va
   //     "Bo loc ATR an toan" (Section 2.4b/2.4d)
   if(InpDCA_UseATRDistance || InpUseATRFilter)
     {
      h_ATR_DCA = iATR(_Symbol, InpDCA_ATR_Timeframe, InpDCA_ATR_Period);
      if(h_ATR_DCA == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iATR (DCA theo ATR / Bo loc ATR)."); allOk = false; }
     }

   if(SignalInUse(Ichimoku_Kumo_Breakout))
     {
      h_Ichimoku = iIchimoku(_Symbol, InpSignalTimeframe, InpIchimoku_Tenkan, InpIchimoku_Kijun, InpIchimoku_Senkou);
      if(h_Ichimoku == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iIchimoku."); allOk = false; }
     }

   if(SignalInUse(Custom_iCustom))
     {
      if(InpCustomIndicatorName == "")
        {
         Print("[Huuoaifx DCA] Loi: Da chon Custom_iCustom nhung InpCustomIndicatorName dang rong.");
         allOk = false;
        }
      else
        {
         // Ghi chu: chi bao Custom mac dinh khong tham so ngoai Symbol/Timeframe.
         // Neu chi bao cua ban can them tham so dau vao, hay bo sung truc tiep vao loi goi iCustom() ben duoi.
         h_Custom = iCustom(_Symbol, InpSignalTimeframe, InpCustomIndicatorName);
         if(h_Custom == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iCustom: ", InpCustomIndicatorName); allOk = false; }
        }
     }

   if(SignalInUse(Smart_Internal_Follow, Smart_Internal_Reverse))
     {
      h_MA_Fast = iMA(_Symbol, InpSignalTimeframe, InpSmartFastMA, 0, MODE_EMA, stdPrice);
      h_MA_Slow = iMA(_Symbol, InpSignalTimeframe, InpSmartSlowMA, 0, MODE_EMA, stdPrice);
      if(h_MA_Fast == INVALID_HANDLE || h_MA_Slow == INVALID_HANDLE)
        { Print("[Huuoaifx DCA] Loi tao handle iMA (Smart Internal)."); allOk = false; }
     }

   if(SignalInUse(Smart_Trend_Follow, Smart_Trend_Reverse))
     {
      h_MA_Trend = iMA(_Symbol, InpSignalTimeframe, InpSmartTrendMA, 0, MODE_EMA, stdPrice);
      if(h_MA_Trend == INVALID_HANDLE) { Print("[Huuoaifx DCA] Loi tao handle iMA (Smart Trend)."); allOk = false; }
     }

   // Ghi chu: Smart_Swing_Follow/Reverse, Color_Candle, Random, Pinbar_Pattern,
   // Engulfing_Pattern, Pinbar_Engulfing_Combo va Always_On khong can Indicator
   // Handle - tinh toan truc tiep tu du lieu OHLC (CopyHigh/Low/Open/Close).
   return(allOk);
  }

//----------------------------------------------------------------------
// 5.14 Giai phong toan bo Indicator Handle da tao (goi trong OnDeinit)
//----------------------------------------------------------------------
void ReleaseIndicatorHandles()
  {
   int handles[];
   ArrayResize(handles, 17);
   handles[0]  = h_CCI;
   handles[1]  = h_Stoch;
   handles[2]  = h_RSI;
   handles[3]  = h_Momentum;
   handles[4]  = h_BB;
   handles[5]  = h_ATR_Supertrend;
   handles[6]  = h_ATR_UTBOT;
   handles[7]  = h_Ichimoku;
   handles[8]  = h_Custom;
   handles[9]  = h_MA_Fast;
   handles[10] = h_MA_Slow;
   handles[11] = h_MACD;
   handles[12] = h_EMA_Filter;
   handles[13] = h_EMA2_Filter;
   handles[14] = h_RSI_Filter;
   handles[15] = h_ADX_Filter;
   handles[16] = h_ATR_DCA;

   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE)
         IndicatorRelease(handles[i]);

   if(h_MA_Trend != INVALID_HANDLE)
      IndicatorRelease(h_MA_Trend);

   h_CCI = h_Stoch = h_RSI = h_Momentum = h_BB = INVALID_HANDLE;
   h_ATR_Supertrend = h_ATR_UTBOT = h_Ichimoku = h_Custom = INVALID_HANDLE;
   h_MA_Fast = h_MA_Slow = h_MA_Trend = INVALID_HANDLE;
   h_MACD = INVALID_HANDLE;
   h_EMA_Filter = INVALID_HANDLE;
   h_EMA2_Filter = INVALID_HANDLE;
   h_RSI_Filter = INVALID_HANDLE;
   h_ADX_Filter = INVALID_HANDLE;
   h_ATR_DCA = INVALID_HANDLE;
  }

//======================================================================
// 6. HAM KHOI TAO / GIAI PHONG (INIT / DEINIT)
//======================================================================
int OnInit()
  {
// --- 6.1 Cau hinh doi tuong CTrade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();
   trade.LogLevel(LOG_LEVEL_ERRORS);

   symbolInfo.Name(_Symbol);
   symbolInfo.RefreshRates();

// --- 6.2 Auto-detect Digits/Pip/Point tuong thich 2-3-4-5 chu so
   DetectSymbolParams();

// --- CHONG TRUOT KHUNG THOI GIAN (Fatal Bug #3): chot CUNG mot khung thoi gian cua
//     Chart dang chay EA ngay tai thoi diem khoi dong (_Period), luu vao g_chartTF de
//     toan bo logic nen cua DCA dung XUYEN SUOT ca vong doi EA, KHONG bi anh huong neu
//     Nguoi dung doi Timeframe hien thi cua Chart sau do.
   g_chartTF = _Period;

// --- 6.3 Khoi tao 4 khung gio giao dich
   InitSessions();

// --- 6.4 Reset trang thai 2 chuoi lenh Buy/Sell
   ResetSequenceState(g_buySeq);
   ResetSequenceState(g_sellSeq);

// --- 6.5 Kiem tra tinh hop le toan bo Input
   if(!ValidateInputs())
     {
      Print("[Huuoaifx DCA] EA dung khoi tao do Input khong hop le. Vui long kiem tra lai thong so.");
      return(INIT_PARAMETERS_INCORRECT);
     }

// --- 6.6 Tao Indicator Handle cho Signal Engine (chi tao loai dang duoc chon)
   if(!CreateIndicatorHandles())
     {
      Print("[Huuoaifx DCA] EA dung khoi tao do tao Indicator Handle that bai.");
      ReleaseIndicatorHandles();
      return(INIT_FAILED);
     }

// --- 6.7 In log tom tat
   PrintStartupSummary();

// --- 6.8 Don dep object Dashboard cu (neu con sot lai tu lan chay truoc)
   ObjectsDeleteAll(0, HUD_PREFIX);

// --- 6.9 Khoi tao bien throttle / cache thoi gian nen
   g_lastVirtualCheckMs = GetTickCount();
   g_lastTickTime       = 0;
   g_sigCache.barTime   = 0;      // ep tinh lai toan bo tin hieu ngay lan check dau tien
   g_lastStepBarTime    = 0;
   g_lastChartBarTime   = iTime(_Symbol, g_chartTF, 0);
   ArrayFree(g_vLevels);
   g_hedge.active = false;

// --- 6.10a Reset trang thai cac nut HUD tuong tac (Stop Buy/Sell, Reset Lots)
//           ve mac dinh moi lan EA khoi dong/gan lai/compile lai.
   g_manualStopBuy  = false;
   g_manualStopSell = false;
   g_forceInitialLotBuy  = false;
   g_forceInitialLotSell = false;

// --- 6.10b Khoi tao theo doi Max Floating Drawdown va Che do Xo So
   g_peakEquity            = AccountInfoDouble(ACCOUNT_EQUITY);
   g_maxFloatingDD_Money   = 0.0;
   g_maxFloatingDD_Percent = 0.0;
   g_lotteryStartEquity    = InpEnableLotteryMode ? AccountInfoDouble(ACCOUNT_EQUITY) : 0.0;
   g_lotteryTargetHit      = false;
   if(InpEnableLotteryMode)
      PrintFormat("[Huuoaifx DCA] XO SO MODE: Da bat, Equity bat dau = %.2f, Target = x%.2f (%.2f).",
                  g_lotteryStartEquity, InpLotteryTargetMultiplier, g_lotteryStartEquity * InpLotteryTargetMultiplier);

// --- 6.11 Dong bo ngay trang thai chuoi Buy/Sell/Hedge tu Position dang mo san
//          co (truong hop gan EA vao chart da co lenh tu lan chay truoc)
   g_dailyDayStamp = 0; // Ep tinh lai moc Equity dau ngay ngay lan CheckDailyReset() dau tien
   CheckDailyReset();
   SyncSequenceFromPositions();

   if(InpUseTimeFilter && !InpSession1_Enable && !InpSession2_Enable && !InpSession3_Enable && !InpSession4_Enable)
      Print("[Huuoaifx DCA] Canh bao: InpUseTimeFilter=true nhung khong Session nao duoc bat -> EA se KHONG bao gio mo chuoi moi.");

   EventSetMillisecondTimer(MathMax(InpVirtualCheckMs, 50));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ReleaseIndicatorHandles();
   ObjectsDeleteAll(0, HUD_PREFIX);
   Comment("");
  }

//======================================================================
// 8. SIGNAL ENGINE - Tinh toan tin hieu vao lenh cho 24 lua chon
//    ENUM_SIGNAL_TRIGGER. Toan bo ket qua duoc cache theo tung nen moi
//    cua InpSignalTimeframe (xem SSignalCache/EnsureSignalCacheFresh)
//    de tranh goi CopyBuffer/CopyRates lap lai nhieu lan trong 1 tick.
//======================================================================

//----------------------------------------------------------------------
// 8.1 Ham phu: dao nguoc tin hieu (dung cho cac bien the *_Reverse)
//----------------------------------------------------------------------
int ApplyReverse(const int bias, const bool reverse)
  {
   if(!reverse) return(bias);
   if(bias == 1)  return(-1);
   if(bias == -1) return(1);
   return(0);
  }

//----------------------------------------------------------------------
// 8.2 Lam moi Cache khi co 1 nen moi hinh thanh tren InpSignalTimeframe
//----------------------------------------------------------------------
void EnsureSignalCacheFresh()
  {
   datetime curBarTime = iTime(_Symbol, InpSignalTimeframe, 0);
   if(curBarTime == 0 || curBarTime == g_sigCache.barTime)
      return; // Van trong cung 1 nen -> giu nguyen cache, khong tinh lai

   g_sigCache.barTime = curBarTime;

   g_sigCache.cciDone = false;   g_sigCache.stochDone = false;
   g_sigCache.rsiDone = false;   g_sigCache.momDone = false;
   g_sigCache.bbDone = false;    g_sigCache.candleDone = false;
   g_sigCache.randomDone = false;
   g_sigCache.supertrendDone = false; g_sigCache.utbotDone = false;
   g_sigCache.ichimokuDone = false;   g_sigCache.customDone = false;
   g_sigCache.smartTrendDone = false; g_sigCache.smartInternalDone = false;
   g_sigCache.smartSwingDone = false;
   g_sigCache.pinbarDone = false; g_sigCache.engulfingDone = false;
   g_sigCache.macdDone = false; g_sigCache.emaFilterDone = false;
  }

//----------------------------------------------------------------------
// 8.3 Ham phu doc du lieu OHLC/Buffer theo THU TU THOI GIAN TANG DAN
//     (i=0 la nen CU NHAT trong cua so) - phuc vu cac thuat toan tinh
//     lap (Supertrend, UTBOT) can duyet tuan tu tu qua khu -> hien tai.
//----------------------------------------------------------------------
bool FetchChronoOHLC(const ENUM_TIMEFRAMES tf, const int count, const int startShift,
                      double &outHigh[], double &outLow[], double &outClose[])
  {
   double h[], l[], c[];
   if(CopyHigh(_Symbol, tf, startShift, count, h)  < count) return(false);
   if(CopyLow(_Symbol, tf, startShift, count, l)   < count) return(false);
   if(CopyClose(_Symbol, tf, startShift, count, c) < count) return(false);
   ArraySetAsSeries(h, true);
   ArraySetAsSeries(l, true);
   ArraySetAsSeries(c, true);

   ArrayResize(outHigh, count);
   ArrayResize(outLow, count);
   ArrayResize(outClose, count);
   for(int i = 0; i < count; i++)
     {
      int src = count - 1 - i;
      outHigh[i]  = h[src];
      outLow[i]   = l[src];
      outClose[i] = c[src];
     }
   return(true);
  }

bool FetchChronoBuffer(const int handle, const int bufferIdx, const int count, const int startShift, double &outArr[])
  {
   double a[];
   if(CopyBuffer(handle, bufferIdx, startShift, count, a) < count) return(false);
   ArraySetAsSeries(a, true);
   ArrayResize(outArr, count);
   for(int i = 0; i < count; i++)
      outArr[i] = a[count - 1 - i];
   return(true);
  }

//----------------------------------------------------------------------
// 8.4 CAC HAM TINH BIAS (-1 Sell / 0 None / 1 Buy) - MOI HAM TU CACHE
//     KET QUA THEO NEN, CHI TINH LAI KHI EnsureSignalCacheFresh() reset.
//----------------------------------------------------------------------

// --- CCI: Qua ban (<=LevelDown) -> Mua (dao chieu) | Qua mua (>=LevelUp) -> Ban
int BiasFromCCI()
  {
   if(g_sigCache.cciDone) return(g_sigCache.cciBias);
   g_sigCache.cciDone = true;
   g_sigCache.cciBias = 0;
   if(h_CCI == INVALID_HANDLE) return(0);

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_CCI, 0, 1, 1, buf) < 1) return(0);

   int bias = 0;
   if(buf[0] <= InpCCI_LevelDown)      bias = 1;
   else if(buf[0] >= InpCCI_LevelUp)   bias = -1;

   g_sigCache.cciBias = bias;
   return(bias);
  }

// --- Stochastic: Cat len tu vung qua ban -> Mua | Cat xuong tu vung qua mua -> Ban
int BiasFromStochastic()
  {
   if(g_sigCache.stochDone) return(g_sigCache.stochBias);
   g_sigCache.stochDone = true;
   g_sigCache.stochBias = 0;
   if(h_Stoch == INVALID_HANDLE) return(0);

   double kBuf[], dBuf[];
   ArraySetAsSeries(kBuf, true);
   ArraySetAsSeries(dBuf, true);
   if(CopyBuffer(h_Stoch, 0, 1, 2, kBuf) < 2) return(0);
   if(CopyBuffer(h_Stoch, 1, 1, 2, dBuf) < 2) return(0);

   double kCur = kBuf[0], kPrev = kBuf[1];
   double dCur = dBuf[0], dPrev = dBuf[1];

   int bias = 0;
   if(kPrev <= dPrev && kCur > dCur && kCur <= InpStoch_LevelDown)
      bias = 1;
   else if(kPrev >= dPrev && kCur < dCur && kCur >= InpStoch_LevelUp)
      bias = -1;

   g_sigCache.stochBias = bias;
   return(bias);
  }

// --- RSI: <=LevelDown -> Mua | >=LevelUp -> Ban
int BiasFromRSI()
  {
   if(g_sigCache.rsiDone) return(g_sigCache.rsiBias);
   g_sigCache.rsiDone = true;
   g_sigCache.rsiBias = 0;
   if(h_RSI == INVALID_HANDLE) return(0);

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_RSI, 0, 1, 1, buf) < 1) return(0);

   int bias = 0;
   if(buf[0] <= InpRSI_LevelDown)    bias = 1;
   else if(buf[0] >= InpRSI_LevelUp) bias = -1;

   g_sigCache.rsiBias = bias;
   return(bias);
  }

// --- Momentum: Vuot nguong tren (100+Level) -> Mua | Vuot nguong duoi (100-Level) -> Ban
int BiasFromMomentum()
  {
   if(g_sigCache.momDone) return(g_sigCache.momBias);
   g_sigCache.momDone = true;
   g_sigCache.momBias = 0;
   if(h_Momentum == INVALID_HANDLE) return(0);

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_Momentum, 0, 1, 1, buf) < 1) return(0);

   int bias = 0;
   if(buf[0] >= InpMomentum_LevelUp)        bias = 1;
   else if(buf[0] <= InpMomentum_LevelDown) bias = -1;

   g_sigCache.momBias = bias;
   return(bias);
  }

// --- Bollinger Bands: Cham/Pha dai duoi -> Mua | Cham/Pha dai tren -> Ban (Mean Reversion)
int BiasFromBollinger()
  {
   if(g_sigCache.bbDone) return(g_sigCache.bbBias);
   g_sigCache.bbDone = true;
   g_sigCache.bbBias = 0;
   if(h_BB == INVALID_HANDLE) return(0);

   double upperBuf[], lowerBuf[];
   ArraySetAsSeries(upperBuf, true);
   ArraySetAsSeries(lowerBuf, true);
   if(CopyBuffer(h_BB, 1, 1, 1, upperBuf) < 1) return(0);
   if(CopyBuffer(h_BB, 2, 1, 1, lowerBuf) < 1) return(0);

   double price = iClose(_Symbol, InpSignalTimeframe, 1);
   int bias = 0;
   if(price <= lowerBuf[0])      bias = 1;
   else if(price >= upperBuf[0]) bias = -1;

   g_sigCache.bbBias = bias;
   return(bias);
  }

// --- MACD Filter: MACD Line > Signal Line -> Thien Mua | MACD Line < Signal Line -> Thien Ban.
//     Day la BO LOC XAC NHAN BO SUNG (AND-gate voi tin hieu chinh trong IsSignalConfirmed()),
//     KHONG PHAI 1 lua chon rieng trong ENUM_SIGNAL_TRIGGER - chi co tac dung khi InpUseMACDFilter=true.
int BiasFromMACD()
  {
   if(g_sigCache.macdDone) return(g_sigCache.macdBias);
   g_sigCache.macdDone = true;
   g_sigCache.macdBias = 0;
   if(!InpUseMACDFilter || h_MACD == INVALID_HANDLE) return(0);

   double mainBuf[], signalBuf[];
   ArraySetAsSeries(mainBuf, true);
   ArraySetAsSeries(signalBuf, true);
   if(CopyBuffer(h_MACD, 0, 1, 1, mainBuf)   < 1) return(0);
   if(CopyBuffer(h_MACD, 1, 1, 1, signalBuf) < 1) return(0);

   int bias = 0;
   if(mainBuf[0] > signalBuf[0])      bias = 1;
   else if(mainBuf[0] < signalBuf[0]) bias = -1;

   g_sigCache.macdBias = bias;
   return(bias);
  }

// --- Bo loc EMA Trend (EMA 1): Gia dong > EMA1 -> CHI cho phep BUY | Gia dong < EMA1 -> CHI
//     cho phep SELL. Dung CHUNG cho ca "Bo loc EMA" (2.18, AND-gate InpUseEMAFilter) VA
//     "Bo loc trend cho DCA" (2.4, InpUseDCATrendFilter) - ca 2 doc lap nhau, chi khac nhau
//     o CHO GOI (IsSignalConfirmed vs ShouldOpenDCA). Khong tu gate theo Input o day - cac
//     noi GOI ham nay tu kiem tra Input cua rieng minh truoc khi su dung ket qua.
int BiasFromEMAFilter()
  {
   if(g_sigCache.emaFilterDone) return(g_sigCache.emaFilterBias);
   g_sigCache.emaFilterDone = true;
   g_sigCache.emaFilterBias = 0;
   if(h_EMA_Filter == INVALID_HANDLE) return(0);

   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);
   if(CopyBuffer(h_EMA_Filter, 0, 1, 1, emaBuf) < 1) return(0);

   double price = iClose(_Symbol, InpEMA_Timeframe, 1);
   int bias = 0;
   if(price > emaBuf[0])      bias = 1;   // Tren EMA1 -> chi cho phep BUY
   else if(price < emaBuf[0]) bias = -1;  // Duoi EMA1 -> chi cho phep SELL

   g_sigCache.emaFilterBias = bias;
   return(bias);
  }

// --- Bo loc EMA (2.18) - 2 dieu kien BO SUNG rieng cho bo loc nay (khong anh huong
//     "Bo loc trend cho DCA"): (1) Khoang cach |Gia - EMA1| khong duoc vuot qua
//     InpEMA_MaxDistPips (gia da "chay" qua xa EMA thi khong xac nhan them lenh moi
//     de tranh duoi dinh/day); (2) Khoang cach |EMA1 - EMA2| phai >= InpEMA_MinGapPips
//     (2 EMA phai thuc su tach xu huong ro rang, tranh vung EMA dan nhau/sideway).
bool EMAFilterExtraChecksOk()
  {
   if(h_EMA_Filter == INVALID_HANDLE) return(true);

   double price = iClose(_Symbol, InpEMA_Timeframe, 1);
   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);
   if(CopyBuffer(h_EMA_Filter, 0, 1, 1, emaBuf) < 1) return(true);

   if(InpEMA_MaxDistPips > 0.0 && PriceToPips(MathAbs(price - emaBuf[0])) > InpEMA_MaxDistPips)
      return(false);

   if(InpEMA_MinGapPips > 0.0 && h_EMA2_Filter != INVALID_HANDLE)
     {
      double ema2Buf[];
      ArraySetAsSeries(ema2Buf, true);
      if(CopyBuffer(h_EMA2_Filter, 0, 1, 1, ema2Buf) >= 1)
         if(PriceToPips(MathAbs(emaBuf[0] - ema2Buf[0])) < InpEMA_MinGapPips)
            return(false);
     }

   return(true);
  }

// --- Bo loc RSI (2.18): RSI >= LevelUp -> chi cho phep BUY | RSI <= LevelDown -> chi cho
//     phep SELL. La BO LOC XAC NHAN BO SUNG (AND-gate) doc lap voi ENUM_SIGNAL_TRIGGER RSI.
int BiasFromRSIFilter()
  {
   if(h_RSI_Filter == INVALID_HANDLE) return(0);

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_RSI_Filter, 0, 1, 1, buf) < 1) return(0);

   int bias = 0;
   if(buf[0] >= InpRSIFilter_LevelUp)        bias = 1;
   else if(buf[0] <= InpRSIFilter_LevelDown) bias = -1;

   return(bias);
  }

// --- Bo loc Zone Cycle (2.18): chi cho phep Buy khi Gia <= Vung gia duoi, chi cho phep
//     Sell khi Gia >= Vung gia tren (grid xoay vong trong bien do gia - mean reversion).
bool ZoneCycleAllows(const int direction)
  {
   if(!InpUseZoneCycle) return(true);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(direction == 1)  return(price <= InpZoneCyclePriceLower);
   return(price >= InpZoneCyclePriceUpper);
  }

// --- Color Candle: Nen tang -> Mua | Nen giam -> Ban (tin hieu thuan xu huong don gian)
int BiasFromColorCandle()
  {
   if(g_sigCache.candleDone) return(g_sigCache.candleBias);
   g_sigCache.candleDone = true;

   double o = iOpen(_Symbol, InpSignalTimeframe, 1);
   double c = iClose(_Symbol, InpSignalTimeframe, 1);

   int bias = 0;
   if(c > o)      bias = 1;
   else if(c < o) bias = -1;

   g_sigCache.candleBias = bias;
   return(bias);
  }

// --- Random: Tin hieu ngau nhien, giu nguyen trong suot 1 nen de nhat quan
int BiasFromRandom()
  {
   if(g_sigCache.randomDone) return(g_sigCache.randomBias);
   g_sigCache.randomDone = true;

   int r = MathRand() % 3; // 0,1,2
   int bias = (r == 0) ? -1 : (r == 1 ? 0 : 1);

   g_sigCache.randomBias = bias;
   return(bias);
  }

// --- Supertrend (tu tinh tu ATR): Bias = 1/-1 THEO HUONG TREND HIEN TAI, lien tuc (BAM
//     XU HUONG) - mien gia dang o phia Tang/Giam cua duong Supertrend la con tra ve bias
//     tuong ung, khong doi den dung khoanh khac vua doi mau (flip) nhu ban truoc. Phu hop
//     EA kieu DCA/Grid can vao lenh deu tay theo dung xu huong dang chay, thay vi chi vao
//     dung 1 nen luc dao chieu roi bo lo neu tin hieu khac (Spread/Session/...) tam thoi
//     chan ngay luc do. (Da doi theo yeu cau nguoi dung ngay 2026-08-23.)
int BiasFromSupertrend()
  {
   if(g_sigCache.supertrendDone) return(g_sigCache.supertrendBias);
   g_sigCache.supertrendDone = true;
   g_sigCache.supertrendBias = 0;
   if(h_ATR_Supertrend == INVALID_HANDLE) return(0);

   int n = 100;
   double h2[], l2[], c2[], a2[];
   if(!FetchChronoOHLC(InpSignalTimeframe, n, 1, h2, l2, c2)) return(0);
   if(!FetchChronoBuffer(h_ATR_Supertrend, 0, n, 1, a2))      return(0);

   double upBand[], dnBand[];
   int    trendArr[];
   ArrayResize(upBand, n); ArrayResize(dnBand, n); ArrayResize(trendArr, n);

   for(int i = 0; i < n; i++)
     {
      double mid     = (h2[i] + l2[i]) / 2.0;
      double basicUp = mid + InpSupertrend_Multiplier * a2[i];
      double basicDn = mid - InpSupertrend_Multiplier * a2[i];

      if(i == 0)
        {
         upBand[i] = basicUp; dnBand[i] = basicDn; trendArr[i] = 1;
         continue;
        }

      upBand[i] = (basicUp < upBand[i-1] || c2[i-1] > upBand[i-1]) ? basicUp : upBand[i-1];
      dnBand[i] = (basicDn > dnBand[i-1] || c2[i-1] < dnBand[i-1]) ? basicDn : dnBand[i-1];

      if(trendArr[i-1] == 1)
         trendArr[i] = (c2[i] < dnBand[i]) ? -1 : 1;
      else
         trendArr[i] = (c2[i] > upBand[i]) ? 1 : -1;
     }

   int bias = trendArr[n-1]; // Bam theo huong trend hien tai (khong con gioi han "chi luc flip")

   g_sigCache.supertrendBias = bias;
   return(bias);
  }

// --- UTBOT Signal (ATR Trailing Stop kieu "UT Bot Alerts"): Bias khi gia CAT QUA Trailing Stop
int BiasFromUTBot()
  {
   if(g_sigCache.utbotDone) return(g_sigCache.utbotBias);
   g_sigCache.utbotDone = true;
   g_sigCache.utbotBias = 0;
   if(h_ATR_UTBOT == INVALID_HANDLE) return(0);

   int n = 100;
   double h2[], l2[], c2[], a2[];
   if(!FetchChronoOHLC(InpSignalTimeframe, n, 1, h2, l2, c2)) return(0);
   if(!FetchChronoBuffer(h_ATR_UTBOT, 0, n, 1, a2))           return(0);

   double stop[]; int dir[];
   ArrayResize(stop, n); ArrayResize(dir, n);

   for(int i = 0; i < n; i++)
     {
      double nLoss = InpUTBOT_KeyValue * a2[i];
      if(i == 0)
         stop[i] = c2[i] - nLoss;
      else if(c2[i] > stop[i-1] && c2[i-1] > stop[i-1])
         stop[i] = MathMax(stop[i-1], c2[i] - nLoss);
      else if(c2[i] < stop[i-1] && c2[i-1] < stop[i-1])
         stop[i] = MathMin(stop[i-1], c2[i] + nLoss);
      else if(c2[i] > stop[i-1])
         stop[i] = c2[i] - nLoss;
      else
         stop[i] = c2[i] + nLoss;

      dir[i] = (c2[i] > stop[i]) ? 1 : -1;
     }

   int bias = 0;
   if(dir[n-1] == 1 && dir[n-2] == -1)       bias = 1;
   else if(dir[n-1] == -1 && dir[n-2] == 1)  bias = -1;

   g_sigCache.utbotBias = bias;
   if(bias != 0 && InpUTBOT_ShowArrows) DrawUTBotArrow(bias, iTime(_Symbol, InpSignalTimeframe, 1));
   return(bias);
  }

// --- Ve 1 mui ten UTBOT tren Chart tai nen vua xac nhan tin hieu (chi 1 lan/nen vi
//     ham nay chi duoc goi tu trong BiasFromUTBot() - da qua cache theo nen moi).
//     InpUTBOT_ArrowDist: khoang cach (tinh bang Point) day mui ten ra xa nen de tranh
//     de len than/rau nen, giup nhin ro tren Chart khi nhieu tin hieu lien tiep.
void DrawUTBotArrow(const int bias, const datetime barTime)
  {
   string name = HUD_PREFIX + "UTBOT_" + IntegerToString((long)barTime);
   if(ObjectFind(0, name) >= 0) return; // Da ve cho nen nay roi

   double offset = InpUTBOT_ArrowDist * g_sym.point;
   double price = (bias == 1) ? (iLow(_Symbol, InpSignalTimeframe, 1) - offset)
                               : (iHigh(_Symbol, InpSignalTimeframe, 1) + offset);

   ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (bias == 1) ? 233 : 234); // Wingdings: len/xuong
   ObjectSetInteger(0, name, OBJPROP_COLOR, (bias == 1) ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

// --- Ichimoku Kumo Breakout: Gia pha vo len/xuong khoi vien May (Senkou A/B)
int BiasFromIchimoku()
  {
   if(g_sigCache.ichimokuDone) return(g_sigCache.ichimokuBias);
   g_sigCache.ichimokuDone = true;
   g_sigCache.ichimokuBias = 0;
   if(h_Ichimoku == INVALID_HANDLE) return(0);

   // Ghi chu: Buffer SENKOUSPANA/B cua iIchimoku duoc CopyBuffer() tra ve THEO
   // CHI SO TINH TOAN GOC (chua tinh do dich hien thi ve phia truoc InpIchimoku_Kijun
   // nen tren chart). De lay dung vien May DANG AP DUNG cho nen shift=1 hien tai,
   // phai doc gia tri Senkou tai vi tri lui them InpIchimoku_Kijun nen.
   int need = InpIchimoku_Kijun + 3;

   double spanA[], spanB[], closeArr[];
   ArraySetAsSeries(spanA, true);
   ArraySetAsSeries(spanB, true);
   ArraySetAsSeries(closeArr, true);

   if(CopyBuffer(h_Ichimoku, 2, 0, need, spanA) < need) return(0);
   if(CopyBuffer(h_Ichimoku, 3, 0, need, spanB) < need) return(0);
   if(CopyClose(_Symbol, InpSignalTimeframe, 0, need, closeArr) < need) return(0);

   // Gia tri Senkou hien tai duoc VE hien thi tai shift=1 thuc chat da duoc TINH
   // TOAN tu du lieu cua bar shift=(1+Kijun) [xem ghi chu ben tren] -> +1 offset.
   int curIdx  = InpIchimoku_Kijun + 1;
   int prevIdx = InpIchimoku_Kijun + 2;

   double cloudUpperCur  = MathMax(spanA[curIdx],  spanB[curIdx]);
   double cloudLowerCur  = MathMin(spanA[curIdx],  spanB[curIdx]);
   double cloudUpperPrev = MathMax(spanA[prevIdx], spanB[prevIdx]);
   double cloudLowerPrev = MathMin(spanA[prevIdx], spanB[prevIdx]);

   double closeCur  = closeArr[1];
   double closePrev = closeArr[2];

   int bias = 0;
   if(closePrev <= cloudUpperPrev && closeCur > cloudUpperCur)
      bias = 1;
   else if(closePrev >= cloudLowerPrev && closeCur < cloudLowerCur)
      bias = -1;

   g_sigCache.ichimokuBias = bias;
   return(bias);
  }

// --- Custom iCustom: Doc 2 buffer kieu Mui ten (Buy/Sell), EMPTY_VALUE = khong co tin hieu.
//     InpCustomConfirmBars: so nen LIEN TIEP (tinh tu nen dong gan nhat) phai
//     CUNG cho ra 1 chieu tin hieu duy nhat moi duoc xac nhan (mac dinh = 1,
//     tuong duong hanh vi cu chi kiem tra 1 nen).
int BiasFromCustomIndicator()
  {
   if(g_sigCache.customDone) return(g_sigCache.customBias);
   g_sigCache.customDone = true;
   g_sigCache.customBias = 0;
   if(h_Custom == INVALID_HANDLE) return(0);

   int confirmBars = MathMax(InpCustomConfirmBars, 1);

   double buyBuf[], sellBuf[];
   ArraySetAsSeries(buyBuf, true);
   ArraySetAsSeries(sellBuf, true);
   if(CopyBuffer(h_Custom, InpCustomIndicatorBuffer,  1, confirmBars, buyBuf)  < confirmBars) return(0);
   if(CopyBuffer(h_Custom, InpCustomIndicatorBuffer2, 1, confirmBars, sellBuf) < confirmBars) return(0);

   bool allBuy = true, allSell = true;
   for(int i = 0; i < confirmBars; i++)
     {
      bool hasBuy  = (buyBuf[i]  != EMPTY_VALUE && buyBuf[i]  != 0.0);
      bool hasSell = (sellBuf[i] != EMPTY_VALUE && sellBuf[i] != 0.0);
      if(!(hasBuy && !hasSell))  allBuy  = false;
      if(!(hasSell && !hasBuy)) allSell = false;
      if(!allBuy && !allSell) break;
     }

   int bias = 0;
   if(allBuy)       bias = 1;
   else if(allSell) bias = -1;

   g_sigCache.customBias = bias;
   return(bias);
  }

// --- Smart Internal Follow: EMA nhanh vs EMA cham (cau truc noi tai/ngan han)
int BiasFromSmartInternal()
  {
   if(g_sigCache.smartInternalDone) return(g_sigCache.smartInternalBias);
   g_sigCache.smartInternalDone = true;
   g_sigCache.smartInternalBias = 0;
   if(h_MA_Fast == INVALID_HANDLE || h_MA_Slow == INVALID_HANDLE) return(0);

   double fastBuf[], slowBuf[];
   ArraySetAsSeries(fastBuf, true);
   ArraySetAsSeries(slowBuf, true);
   if(CopyBuffer(h_MA_Fast, 0, 1, 1, fastBuf) < 1) return(0);
   if(CopyBuffer(h_MA_Slow, 0, 1, 1, slowBuf) < 1) return(0);

   int bias = 0;
   if(fastBuf[0] > slowBuf[0])      bias = 1;
   else if(fastBuf[0] < slowBuf[0]) bias = -1;

   g_sigCache.smartInternalBias = bias;
   return(bias);
  }

// --- Smart Trend Follow: Gia dong cua so voi EMA xu huong lon (cau truc vi mo)
int BiasFromSmartTrend()
  {
   if(g_sigCache.smartTrendDone) return(g_sigCache.smartTrendBias);
   g_sigCache.smartTrendDone = true;
   g_sigCache.smartTrendBias = 0;
   if(h_MA_Trend == INVALID_HANDLE) return(0);

   double maBuf[];
   ArraySetAsSeries(maBuf, true);
   if(CopyBuffer(h_MA_Trend, 0, 1, 1, maBuf) < 1) return(0);

   double price = iClose(_Symbol, InpSignalTimeframe, 1);
   int bias = 0;
   if(price > maBuf[0])      bias = 1;
   else if(price < maBuf[0]) bias = -1;

   g_sigCache.smartTrendBias = bias;
   return(bias);
  }

// --- Smart Swing Follow: Cau truc Swing High/Low (Fractal tuy chinh InpSmartSwingLookback)
//     Higher-High + Higher-Low => xu huong tang | Lower-High + Lower-Low => xu huong giam
int BiasFromSmartSwing()
  {
   if(g_sigCache.smartSwingDone) return(g_sigCache.smartSwingBias);
   g_sigCache.smartSwingDone = true;
   g_sigCache.smartSwingBias = 0;

   int lb   = MathMax(InpSmartSwingLookback, 1);
   int need = 150;
   if(need < lb * 2 + 10) need = lb * 2 + 10;

   double high[], low[];
   if(CopyHigh(_Symbol, InpSignalTimeframe, 1, need, high) < need) return(0);
   if(CopyLow(_Symbol, InpSignalTimeframe, 1, need, low)   < need) return(0);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   double swingHigh[2]; int foundHigh = 0;
   double swingLow[2];  int foundLow  = 0;

   for(int i = lb; i < need - lb && (foundHigh < 2 || foundLow < 2); i++)
     {
      if(foundHigh < 2)
        {
         bool isHigh = true;
         for(int k = 1; k <= lb && isHigh; k++)
            if(high[i] < high[i-k] || high[i] < high[i+k])
               isHigh = false;
         if(isHigh) { swingHigh[foundHigh] = high[i]; foundHigh++; }
        }
      if(foundLow < 2)
        {
         bool isLow = true;
         for(int k = 1; k <= lb && isLow; k++)
            if(low[i] > low[i-k] || low[i] > low[i+k])
               isLow = false;
         if(isLow) { swingLow[foundLow] = low[i]; foundLow++; }
        }
     }

   if(foundHigh < 2 || foundLow < 2) return(0);

   bool higherHighs = swingHigh[0] > swingHigh[1];
   bool higherLows  = swingLow[0]  > swingLow[1];
   bool lowerHighs  = swingHigh[0] < swingHigh[1];
   bool lowerLows   = swingLow[0]  < swingLow[1];

   int bias = 0;
   if(higherHighs && higherLows)      bias = 1;
   else if(lowerHighs && lowerLows)   bias = -1;

   g_sigCache.smartSwingBias = bias;
   return(bias);
  }

// --- Pinbar Pattern: Rau dai >= ty le * Than va troi hon rau con lai 1.5 lan
int BiasFromPinbar()
  {
   if(g_sigCache.pinbarDone) return(g_sigCache.pinbarBias);
   g_sigCache.pinbarDone = true;
   g_sigCache.pinbarBias = 0;

   double o1 = iOpen(_Symbol, InpSignalTimeframe, 1);
   double h1 = iHigh(_Symbol, InpSignalTimeframe, 1);
   double l1 = iLow(_Symbol, InpSignalTimeframe, 1);
   double c1 = iClose(_Symbol, InpSignalTimeframe, 1);

   double body = MathAbs(c1 - o1);
   if(body <= 0.0) body = g_sym.point;

   double upperWick = h1 - MathMax(o1, c1);
   double lowerWick = MathMin(o1, c1) - l1;

   int bias = 0;
   if(lowerWick >= InpPinbar_WickRatio * body && lowerWick > upperWick * InpPinbar_WickToOppositeRatio && PriceToPips(lowerWick) >= InpPinbar_MinWickPips)
      bias = 1;
   else if(upperWick >= InpPinbar_WickRatio * body && upperWick > lowerWick * InpPinbar_WickToOppositeRatio && PriceToPips(upperWick) >= InpPinbar_MinWickPips)
      bias = -1;

   g_sigCache.pinbarBias = bias;
   return(bias);
  }

// --- Engulfing Pattern: Nen sau "nuot tron" than nen truoc, than >= ty le toi thieu
int BiasFromEngulfing()
  {
   if(g_sigCache.engulfingDone) return(g_sigCache.engulfingBias);
   g_sigCache.engulfingDone = true;
   g_sigCache.engulfingBias = 0;

   double o1 = iOpen(_Symbol, InpSignalTimeframe, 1),  c1 = iClose(_Symbol, InpSignalTimeframe, 1);
   double o2 = iOpen(_Symbol, InpSignalTimeframe, 2),  c2 = iClose(_Symbol, InpSignalTimeframe, 2);
   double h1 = iHigh(_Symbol, InpSignalTimeframe, 1),  l1 = iLow(_Symbol, InpSignalTimeframe, 1);
   double h2 = iHigh(_Symbol, InpSignalTimeframe, 2),  l2 = iLow(_Symbol, InpSignalTimeframe, 2);

   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);
   if(body2 <= 0.0) body2 = g_sym.point;

   // InpEngulfing_FullWickCover=true -> doi hoi nen sau "nuot tron" CA RAU (High/Low),
   // khong chi phan Than (Open/Close) nhu truoc.
   bool wickCoverOk = !InpEngulfing_FullWickCover || (h1 >= h2 && l1 <= l2);
   bool minPipsOk   = (InpEngulfing_MinBodyPips <= 0.0) || (PriceToPips(body1) >= InpEngulfing_MinBodyPips);

   bool bullishEngulf = (c2 < o2) && (c1 > o1) && (o1 <= c2) && (c1 >= o2) && (body1 >= InpEngulfing_MinBodyRatio * body2) && wickCoverOk && minPipsOk;
   bool bearishEngulf = (c2 > o2) && (c1 < o1) && (o1 >= c2) && (c1 <= o2) && (body1 >= InpEngulfing_MinBodyRatio * body2) && wickCoverOk && minPipsOk;

   int bias = 0;
   if(bullishEngulf)      bias = 1;
   else if(bearishEngulf) bias = -1;

   g_sigCache.engulfingBias = bias;
   return(bias);
  }

// --- Pinbar + Engulfing Combo: Can it nhat 1 mau hinh xac nhan, khong duoc xung dot chieu
int BiasFromPinbarEngulfingCombo()
  {
   int pb = BiasFromPinbar();
   int eg = BiasFromEngulfing();

   if(pb == 0 && eg == 0)              return(0);
   if(pb != 0 && eg != 0 && pb != eg)  return(0); // Xung dot chieu -> bo qua de an toan
   return(pb != 0 ? pb : eg);
  }

//----------------------------------------------------------------------
// 8.5 Dispatcher tong: tra ve Bias "goc" (-1/0/1) cho 1 ENUM_SIGNAL_TRIGGER
//     bat ky. Cac bien the *_Reverse dung chung 1 lan tinh voi ban Follow
//     tuong ung (qua ApplyReverse) nen khong ton them chi phi tinh toan.
//----------------------------------------------------------------------
int GetRawBias(const ENUM_SIGNAL_TRIGGER trigger)
  {
   EnsureSignalCacheFresh();
   switch(trigger)
     {
      case CCI:                     return(BiasFromCCI());
      case CCI_Reverse:              return(ApplyReverse(BiasFromCCI(), true));
      case Stochastic:               return(BiasFromStochastic());
      case Stoch_Reverse:            return(ApplyReverse(BiasFromStochastic(), true));
      case RSI:                      return(BiasFromRSI());
      case RSI_Reverse:              return(ApplyReverse(BiasFromRSI(), true));
      case Momentum:                 return(BiasFromMomentum());
      case Bollinger_Bands:          return(BiasFromBollinger());
      case Color_Candle:             return(BiasFromColorCandle());
      case Random:                   return(BiasFromRandom());
      case Supertrend:               return(BiasFromSupertrend());
      case UTBOT_Signal:             return(BiasFromUTBot());
      case Custom_iCustom:           return(BiasFromCustomIndicator());
      case Ichimoku_Kumo_Breakout:   return(BiasFromIchimoku());
      case Smart_Trend_Follow:       return(BiasFromSmartTrend());
      case Smart_Trend_Reverse:      return(ApplyReverse(BiasFromSmartTrend(), true));
      case Smart_Internal_Follow:    return(BiasFromSmartInternal());
      case Smart_Internal_Reverse:   return(ApplyReverse(BiasFromSmartInternal(), true));
      case Smart_Swing_Follow:       return(BiasFromSmartSwing());
      case Smart_Swing_Reverse:      return(ApplyReverse(BiasFromSmartSwing(), true));
      case Pinbar_Pattern:           return(BiasFromPinbar());
      case Engulfing_Pattern:        return(BiasFromEngulfing());
      case Pinbar_Engulfing_Combo:   return(BiasFromPinbarEngulfingCombo());
      case Always_On:                return(0); // Xu ly rieng trong IsSignalConfirmed()
     }
   return(0);
  }

//----------------------------------------------------------------------
// 8.6 API CONG KHAI CUA SIGNAL ENGINE (Grid Engine / Part 5 se goi cac ham nay)
//----------------------------------------------------------------------

// IsSignalConfirmed: tin hieu 'trigger' co xac nhan huong 'direction' (1=Buy,-1=Sell) khong.
// Always_On luon xac nhan (true) bat ke huong - viec chon huong nao thuoc ve tang Orchestration
// (dua theo InpTradeExecution), day chi la lop XAC NHAN dieu kien cho 1 huong cu the.
bool IsSignalConfirmed(const ENUM_SIGNAL_TRIGGER trigger, const int direction)
  {
   if(direction != 1 && direction != -1) return(false);

   bool baseConfirmed = (trigger == Always_On) ? true : (GetRawBias(trigger) == direction);
   if(!baseConfirmed) return(false);

   // Bo loc MACD (neu bat) la AND-gate bo sung: du tin hieu chinh da xac nhan huong 'direction',
   // van can MACD Line dong thuan huong do moi duoc coi la XAC NHAN cuoi cung.
   if(InpUseMACDFilter && BiasFromMACD() != direction) return(false);

   // Bo loc EMA (neu bat) la AND-gate bo sung tuong tu: Gia phai dung phia EMA1 tuong ung
   // voi 'direction', VA phai thoa 2 dieu kien bo sung (Max khoang cach Gia-EMA1 / Min
   // khoang cach EMA1-EMA2 - xem EMAFilterExtraChecksOk()).
   if(InpUseEMAFilter && (BiasFromEMAFilter() != direction || !EMAFilterExtraChecksOk())) return(false);

   // Bo loc RSI (neu bat) la AND-gate bo sung: RSI phai dung phia Level tuong ung.
   if(InpUseRSIFilter && BiasFromRSIFilter() != direction) return(false);

   // Bo loc Zone Cycle (neu bat): chi xac nhan khi Gia dang o dung Vung cho phep huong nay.
   if(!ZoneCycleAllows(direction)) return(false);

   return(true);
  }

// CheckEntrySignal: dung InpEntrySignal de quyet dinh mo CHUOI LENH MOI theo huong nao.
// Uu tien kiem tra Buy truoc, sau do Sell (theo InpTradeExecution cho phep huong nao).
int CheckEntrySignal()
  {
   if(!InpAllowNewSequence) return(0);

   if(InpTradeExecution != Sell_Only && IsSignalConfirmed(InpEntrySignal, 1))
      return(1);
   if(InpTradeExecution != Buy_Only && IsSignalConfirmed(InpEntrySignal, -1))
      return(-1);

   return(0);
  }

// CheckDCASignal: dung InpDCASignal de xac nhan co duoc nhoi them lenh THEO
// DUNG HUONG 'direction' cua chuoi hien tai hay khong (Signal_Based, Dual_Signal_Pyramiding...).
bool CheckDCASignal(const int direction)
  {
   return(IsSignalConfirmed(InpDCASignal, direction));
  }

//======================================================================
// 9. GRID & DCA ENGINE - Logic nhoi lenh, tinh Lot va Partial Closure
//======================================================================

//----------------------------------------------------------------------
// 9.1 Ham phu: gia hien tai co dang di NGUOC (bat loi) so voi huong chuoi khong
//----------------------------------------------------------------------
bool IsAdverseMove(const SSequenceState &seq, const int direction, const double currentPrice)
  {
   double diff = (currentPrice - seq.lastOpenPrice) * direction;
   return(diff < 0.0);
  }

//----------------------------------------------------------------------
// 9.2 Ham phu: tu thoi diem 'sinceTime' den nay da co nen MOI tren khung 'tf' chua
//----------------------------------------------------------------------
bool IsNewBarSince(const ENUM_TIMEFRAMES tf, const datetime sinceTime)
  {
   if(sinceTime <= 0) return(true);

   int shift = iBarShift(_Symbol, tf, sinceTime, false);
   if(shift < 0) return(true); // khong xac dinh duoc vi tri -> cho phep de an toan

   datetime sinceBar = iTime(_Symbol, tf, shift);
   datetime curBar    = iTime(_Symbol, tf, 0);
   return(curBar != sinceBar);
  }

//----------------------------------------------------------------------
// 9.2b CAC BO LOC MOI CHO DCA (UPGRADE v3.0.6, phan tich tu Can Cu Bu Sieng Nang: Bo loc
//      ADX / ATR / Tin tuc / Lich tuan / Chong don cuc gia / Gioi han lenh moi nen). Tat
//      ca deu "an toan mac dinh": neu chua co du lieu Indicator/Calendar (VD moi khoi
//      dong EA, hoac Broker khong ho tro Calendar), KHONG chan lenh (fail-open).
//----------------------------------------------------------------------

// GetDCA_ATRPips: doc gia tri ATR hien tai (nen vua dong, shift 1), quy doi ra Pips.
// Dung chung cho ca "DCA theo ATR" (Section 2.4b) va "Bo loc ATR an toan" (Section 2.4d).
double GetDCA_ATRPips()
  {
   if(h_ATR_DCA == INVALID_HANDLE) return(0.0);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_ATR_DCA, 0, 1, 1, buf) < 1) return(0.0);
   return(PriceToPips(buf[0]));
  }

// ATRSafetyFilterAllows: Bo loc ATR AN TOAN (Section 2.4d) - chan nhoi khi bien dong QUA
// THAP (danh vong, de nhoi lien tuc vo ich, InpATR_MinPips) HOAC QUA CAO (cuc doan/tin
// soc, InpATR_MaxPips). Doc lap voi "DCA theo ATR" (khong lien quan khoang cach nhoi).
bool ATRSafetyFilterAllows()
  {
   if(!InpUseATRFilter) return(true);
   double atrPips = GetDCA_ATRPips();
   if(atrPips <= 0.0) return(true); // Chua co du lieu -> khong chan (an toan)
   if(InpATR_MinPips > 0.0 && atrPips < InpATR_MinPips) return(false);
   if(InpATR_MaxPips > 0.0 && atrPips > InpATR_MaxPips) return(false);
   return(true);
  }

// ADXFilterAllows: Bo loc ADX (Section 2.4c) - chi cho DCA them khi Trend du manh (ADX
// du cao), tranh nhoi day khi thi truong danh vong (sideways/choppy) that thuong.
bool ADXFilterAllows()
  {
   if(!InpUseADXFilter) return(true);
   if(h_ADX_Filter == INVALID_HANDLE) return(true);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_ADX_Filter, 0, 1, 1, buf) < 1) return(true); // Buffer 0 = ADX Main line
   if(buf[0] <= 0.0) return(true);
   return(buf[0] >= InpADX_MinLevel);
  }

// IsHighImpactNewsWindow: Bo loc Tin tuc (Section 2.4e) - dung Economic Calendar noi bo
// cua MT5 (khong can ket noi Internet rieng, du lieu do Terminal/Broker cung cap san).
// Neu Broker/Terminal khong ho tro Calendar (CalendarValueHistory tra ve false) -> khong chan.
// SUA LOI TREO TERMINAL (Fatal Bug #3): CalendarValueHistory()/CalendarEventById() la cac
// lenh goi API Calendar cua Terminal - neu bi goi lien tuc MOI TICK (XAUUSD co the co hang
// chuc tick/giay), Terminal co the bi "treo/lag" do qua tai truy van Calendar lap lai vo ich
// trong khi du lieu Tin tuc thuc te chi thay doi rat cham (vai phut/lan). Them Cache 60 giay:
// chi thuc su goi lai CalendarValueHistory() moi 60 giay 1 lan, cac tick con lai trong cung
// cua so 60 giay do dung THANG ket qua lan truoc (lastNewsResult) - giam tai CPU/API dang ke
// ma khong lam sai lech dieu kien (vung an toan quanh tin thuong tinh bang PHUT, khong phai giay).
bool IsHighImpactNewsWindow()
  {
   if(!InpUseNewsFilter) return(false);

   static datetime lastNewsCheck  = 0;
   static bool     lastNewsResult = false;
   if(TimeCurrent() - lastNewsCheck < 60) return(lastNewsResult);
   lastNewsCheck = TimeCurrent();

   datetime now  = TimeCurrent();
   datetime from = now - (InpNewsMinutesAfter  + 2) * 60;
   datetime to   = now + (InpNewsMinutesBefore + 2) * 60;

   MqlCalendarValue values[];
   if(!CalendarValueHistory(values, from, to, "US", NULL)) { lastNewsResult = false; return(false); }

   for(int i = 0; i < ArraySize(values); i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev)) continue;
      if(InpNewsHighImpactOnly && ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;

      long secDiff = (long)(values[i].time - now);
      if(secDiff >= -InpNewsMinutesAfter * 60 && secDiff <= InpNewsMinutesBefore * 60)
        {
         PrintFormat("[Huuoaifx DCA] Bo loc Tin tuc: dang trong vung an toan quanh tin '%s' (%s) -> Tam dung mo lenh.",
                     ev.name, TimeToString(values[i].time, TIME_DATE | TIME_MINUTES));
         lastNewsResult = true;
         return(true);
        }
     }
   lastNewsResult = false;
   return(false);
  }

// IsWeekdayTradingAllowed: Lich giao dich theo ngay trong tuan (Section 2.17b), tinh theo
// GIO MAY TINH/LAPTOP (TimeLocal) - dong bo cach tinh voi IsWithinTradingSession().
bool IsWeekdayTradingAllowed()
  {
   if(!InpUseWeeklySchedule) return(true);

   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   switch(dt.day_of_week)
     {
      case 0: return(InpTradeSunday);
      case 1: return(InpTradeMonday);
      case 2: return(InpTradeTuesday);
      case 3: return(InpTradeWednesday);
      case 4: return(InpTradeThursday);
      case 5: return(InpTradeFriday);
      case 6: return(InpTradeSaturday);
     }
   return(true);
  }

// PassesAntiClusterCheck: Chong don cuc gia (Section 2.4f) - tu choi neu gia du kien mo
// lenh qua GAN bat ky lenh nao KHAC da co san trong chuoi (khong chi lenh gan nhat), tranh
// truong hop Requote/Slippage/Spread giat manh khien nhieu lenh vo tinh don cuc 1 vung gia
// (VD "san bop lenh" - fill nhieu lenh gan nhu cung 1 gia thay vi rai deu theo khoang cach).
bool PassesAntiClusterCheck(const SSequenceState &seq, const double candidatePrice)
  {
   if(!InpUseAntiCluster || InpAntiClusterMinPips <= 0.0) return(true);
   for(int i = 0; i < seq.totalOrders; i++)
     {
      double distPips = MathAbs(PriceToPips(candidatePrice - seq.orders[i].openPrice));
      if(distPips < InpAntiClusterMinPips) return(false);
     }
   return(true);
  }

// CountOrdersInCurrentBar: Gioi han so lenh moi trong 1 nen (Section 2.4f) - dem so lenh
// (Entry + DCA) cua RIENG chuoi nay da mo ke tu luc nen hien tai bat dau. SUA LOI TRUOT
// KHUNG THOI GIAN (Fatal Bug #3): dung g_chartTF (chot cung tu OnInit) THAY VI
// PERIOD_CURRENT - neu khong, khi Nguoi dung doi Timeframe hien thi cua Chart giua luc
// dang chay 1 chuoi DCA, moc "nen hien tai" se bi tinh sai theo khung gio MOI, lam sai
// lech het logic gioi han so lenh/nen so voi khung gio da dung cho cac lenh truoc do.
//----------------------------------------------------------------------
int CountOrdersInCurrentBar(const SSequenceState &seq)
  {
   datetime barStart = iTime(_Symbol, g_chartTF, 0);
   int count = 0;
   for(int i = 0; i < seq.totalOrders; i++)
      if(seq.orders[i].openTime >= barStart) count++;
   return(count);
  }

//----------------------------------------------------------------------
// 9.3 ShouldOpenDCA: Kiem tra dieu kien mo THEM 1 lenh trong chuoi hien tai
//     (KHONG dung cho lenh dau tien cua chuoi - do la Entry, xu ly o Part 5).
//----------------------------------------------------------------------
bool ShouldOpenDCA_Core(const SSequenceState &seq, const int direction, const double currentPrice, string &outReason)
  {
   outReason = "OK";

   if(!InpUseDCA) { outReason = "InpUseDCA=false (da TAT DCA)"; return(false); }
   if(!seq.active || seq.totalOrders <= 0) { outReason = "Chuoi chua active/chua co lenh"; return(false); }

   int maxOrdersForSide = (direction == 1) ? InpMaxDCAOrders : InpMaxSellOrders;
   if(seq.totalOrders >= maxOrdersForSide) { outReason = StringFormat("Da dat So lenh DCA toi da (%d/%d)", seq.totalOrders, maxOrdersForSide); return(false); }

   // --- Money TP All khi DCA Signal am / ca 2 chieu dang mo (Section 2.13): thay vi
   //     mo them lenh DCA (tang them rui ro), neu ca Buy va Sell dang cung mo VA da
   //     dat Target Loi nhuan Money TP All (InpAccountTP_Value), uu tien Dong toan bo
   //     CHOT LOI NGAY thay vi nhoi them lenh. MIEN TRU khi Trend Switch dang kich hoat
   //     (g_trendSwitchState != 0) - cung ly do nhu o EvaluateAccountTargets().
   if(InpMoneyTPAllOnDCASignalCond && InpUseAccountTP && g_buySeq.active && g_sellSeq.active && g_trendSwitchState == 0)
     {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double target = InpAccountTP_IsPercent ? (bal * InpAccountTP_Value / 100.0) : InpAccountTP_Value;
      double totalProfit = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + GetHedgeProfit();
      if(target > 0.0 && totalProfit >= target)
        {
         PrintFormat("[Huuoaifx DCA] Money TP All (ca 2 chieu dang mo, truoc khi DCA them): %.2f >= %.2f -> Dong toan bo.", totalProfit, target);
         CloseAllEAOrders();
         g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
         outReason = "Vua kich hoat Money TP All (ca 2 chieu) thay vi DCA them";
         return(false);
        }
     }

   // --- Lots toi da / chuoi (Section 2.2): khi da cham nguong, hoac ngung DCA them
   //     (mac dinh) hoac tu dong dong chuoi de "New Cycle" neu InpNewCycleAtMaxLot=true
   //     (xu ly dong thuc su nam trong OnTick, o day chi CAN NGAN mo them lenh).
   if(InpMaxTotalLot > 0.0 && seq.totalLot >= InpMaxTotalLot) { outReason = StringFormat("Da dat Tong Lot toi da (%.2f/%.2f)", seq.totalLot, InpMaxTotalLot); return(false); }

   // --- Delay toi thieu giua 2 lan mo lenh lien tiep (Section 2.2)
   if(InpOpenOrderDelaySec > 0 && seq.lastOpenTime > 0 &&
      (TimeCurrent() - seq.lastOpenTime) < InpOpenOrderDelaySec)
     { outReason = StringFormat("Dang cho Delay toi thieu giua 2 lenh (con %d giay)", (int)(InpOpenOrderDelaySec - (TimeCurrent() - seq.lastOpenTime))); return(false); }

   // --- Bo loc Margin Level an toan (UPGRADE moi, Section 2.2): tu choi nhoi them DCA
   //     neu Margin Level hien tai (ACCOUNT_MARGIN_LEVEL) dang duoi nguong toi thieu -
   //     tranh nhoi them lam Margin Level tut sau hon, tien gan Stop Out. Fail-open khi
   //     ACCOUNT_MARGIN <= 0 (chua co lenh nao dang giu ky quy -> Margin Level vo nghia,
   //     khong the/khong nen chan).
   if(InpUseMarginProtection)
     {
      double curMarginNow = AccountInfoDouble(ACCOUNT_MARGIN);
      if(curMarginNow > 0.0)
        {
         double marginLevelNow = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         if(marginLevelNow < InpMinMarginLevel)
           { outReason = StringFormat("Bo loc Margin Level: %.1f%% < muc toi thieu %.1f%% - tam dung nhoi them de tranh Stop Out", marginLevelNow, InpMinMarginLevel); return(false); }
        }
     }

   // --- Bo loc trend cho DCA (Section 2.4): sau khi chuoi dat du so lenh kich hoat,
   //     chi tiep tuc DCA khi Gia dang dung phia EMA1 tuong ung voi huong chuoi.
   if(InpUseDCATrendFilter && seq.totalOrders >= InpDCATrendFilterActivateCount)
      if(BiasFromEMAFilter() != direction) { outReason = "Bo loc Trend cho DCA (EMA1) khong dung huong"; return(false); }

   // --- UPGRADE v3.0.6 (Section 2.4c/2.4d/2.4e/2.17b/2.4f): cac bo loc an toan bo sung,
   //     AP DUNG CHUNG cho MOI kieu DCA (khong rieng Step_With_BarClose) - tat ca deu
   //     "an toan mac dinh" (thieu du lieu Indicator/Calendar thi KHONG chan lenh).
   if(InpUseNewsFilter && IsHighImpactNewsWindow()) { outReason = "Dang trong khung gio Tin tuc quan trong (News Filter)"; return(false); }
   if(InpUseWeeklySchedule && !IsWeekdayTradingAllowed()) { outReason = "Ngoai Lich trong tuan cho phep (Weekly Schedule)"; return(false); }
   if(!ADXFilterAllows()) { outReason = StringFormat("Bo loc ADX: ADX hien tai < InpADX_MinLevel (%.1f) -> thi truong chua du manh/trending", InpADX_MinLevel); return(false); }
   if(!ATRSafetyFilterAllows()) { outReason = "Bo loc ATR An toan: Bien dong (ATR) qua thap hoac qua cao ngoai [InpATR_MinPips, InpATR_MaxPips]"; return(false); }
   if(InpUseMaxOrdersPerBar && CountOrdersInCurrentBar(seq) >= InpMaxOrdersPerBar) { outReason = StringFormat("Da dat So lenh toi da / 1 nen (%d)", InpMaxOrdersPerBar); return(false); }

   // --- Khoang cach THUC (da tru Spread): 'currentPrice' la Bid (chuoi Buy) hoac Ask
   //     (chuoi Sell) - cung phia voi Gia "dong lenh ngay bay gio", trong khi
   //     seq.lastOpenPrice la Gia KHOP LENH (Buy khop o Ask, Sell khop o Bid). Vi vay
   //     hieu so tho giua 2 gia nay LUON bao gom san Spread hien tai (VD: Spread dang
   //     rong 40 pip thi vua khop lenh xong 'distPips tho' da ~40 pip, dua tren gia chua
   //     he di dau ca). Tru Spread hien tai ra khoi 'distPips tho' de con lai dung phan
   //     GIA THI TRUONG DA DI CHUYEN THUC SU - giup nguong Pips (InpFixedStepPips/Dynamic
   //     Grid Step) hoat dong dung nhu ten goi bat ke Spread san dang hep hay rong (VD
   //     Vang thuong rat rong vao gio thanh khoan thap dau/cuoi tuan).
   double rawDistPips  = MathAbs(PriceToPips(currentPrice - seq.lastOpenPrice));
   double curSpreadPips = PriceToPips(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double distPips = MathMax(0.0, rawDistPips - curSpreadPips);
   int    idx       = seq.totalOrders; // So lenh da co = chi so (0-based) cua lenh DCA sap mo
   double stepPips  = GetDCAStepPips(idx); // Pips co dinh HOAC theo bang Dynamic Grid Step (Section 5.5b)

   // --- Chuyen sang Kieu DCA moi (Section 2.4) sau khi dat du so lenh kich hoat
   ENUM_DCA_METHOD effMethod = InpDCAMethod;
   if(InpDCAMethodSwitchCount > 0 && seq.totalOrders >= InpDCAMethodSwitchCount)
      effMethod = InpDCAMethodAlt;

   switch(effMethod)
     {
      case Fixed_Step:
        {
         if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang di THUAN chieu (chua bat loi) - Fixed_Step can bat loi"; return(false); }
         if(distPips < stepPips) { outReason = StringFormat("Chua du khoang cach Fixed_Step (%.1f/%.1f pip)", distPips, stepPips); return(false); }
         return(true);
        }

      case Step_With_Timeframe:
        {
         if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang di THUAN chieu (chua bat loi) - Step_With_Timeframe can bat loi"; return(false); }
         if(distPips < stepPips) { outReason = StringFormat("Chua du khoang cach (%.1f/%.1f pip)", distPips, stepPips); return(false); }
         if(!IsNewBarSince(InpStepTimeframe, seq.lastOpenTime)) { outReason = "Chua co nen MOI tren InpStepTimeframe ke tu lenh cuoi"; return(false); }
         return(true);
        }

      case Step_Multiplied:
        {
         if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang di THUAN chieu (chua bat loi) - Step_Multiplied can bat loi"; return(false); }
         double step = stepPips * MathPow(InpStepMultiplierFactor, idx);
         if(InpMaxStepPips > 0.0 && step > InpMaxStepPips) step = InpMaxStepPips;
         if(distPips < step) { outReason = StringFormat("Chua du khoang cach Step_Multiplied (%.1f/%.1f pip)", distPips, step); return(false); }
         return(true);
        }

      case Signal_Based:
        {
         if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang di THUAN chieu (chua bat loi) - Signal_Based can bat loi"; return(false); }
         if(distPips < stepPips) { outReason = StringFormat("Chua du khoang cach (%.1f/%.1f pip)", distPips, stepPips); return(false); }
         if(!CheckDCASignal(direction)) { outReason = "Chua co Tin hieu DCA (InpDCASignal) xac nhan dung huong"; return(false); }
         return(true);
        }

      case Step_With_BarClose:
        {
         // --- SUA LOI TRUOT KHUNG THOI GIAN (Fatal Bug #3): toan bo logic nen cua nhanh
         //     Step_With_BarClose (Gia dong/Gia song lay tu PERIOD_CURRENT truoc day) NAY
         //     DUNG g_chartTF (khung thoi gian da CHOT CUNG tu luc EA khoi dong, xem
         //     Section 4/OnInit) - dam bao logic "1 nen" luon nhat quan xuyen suot ca
         //     chuoi DCA, du Nguoi dung co doi Timeframe hien thi cua Chart giua chung.
         //
         //     UPGRADE (mac dinh moi tu ban phan tich Can Cu Bu Sieng Nang): dung dung
         //     nghia den "Dong nen" - CHO 1 cay NEN THUC SU DONG roi moi xet khoang cach,
         //     dung GIA DONG (Close) cua cay nen vua hoan tat, THAY VI kiem tra Gia dang
         //     chay (Tick song) ngay khi vua buoc sang nen moi (hanh vi CU). Ly do: trong
         //     1 cu giat manh (nen co bong/rau dai), Gia co the xuyen qua nguong roi bat
         //     nguoc lai TRUOC KHI nen do dong - kieu cu se nhoi hop ngay giua cu giat,
         //     kieu moi se BO QUA muc do (coi la "khong dang tin"), gom lai thanh 1
         //     khoang cach lon hon o cay nen tiep theo THUC SU dong vuot nguong - giup
         //     tranh nhoi lenh dung dinh/day cua cu giat roi bi hoi nguoc ngay lap tuc.
         if(!InpRequireBarClose)
           {
            // Tat xac nhan dong nen (tuong thich nguoc) -> quay ve hanh vi CU: kiem tra
            // Gia song ngay khi vua sang nen moi.
            if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang di THUAN chieu (chua bat loi)"; return(false); }
            double stepLive = stepPips;
            if(InpDCA_UseATRDistance)
              {
               double atrPipsLive = GetDCA_ATRPips();
               if(atrPipsLive > 0.0 && InpDCA_ATR_StormPips > 0.0 && atrPipsLive >= InpDCA_ATR_StormPips)
                  stepLive = MathMax(stepLive, atrPipsLive * InpDCA_ATR_Multiplier);
              }
            // --- Candle Velocity Step (UPGRADE moi, Section 2.4b): neu THAN nen g_chartTF
            //     vua dong (shift 1) dai gap >= InpVelocityRatio lan ATR (nen "giat" qua nhanh -
            //     tin soc/bien dong dot bien), keo gian them khoang cach nhoi toi thieu len (nhan
            //     dung InpVelocityRatio - dung chung 1 Input lam ca Nguong VA He so nhan, dung
            //     nhu ten goi "He so nhan Step khi nen dai gap X lan ATR"). Doc lap voi "DCA theo
            //     ATR" (InpDCA_UseATRDistance) o tren - lay MAX giua 2 co che, khong cong don.
            if(InpUseVelocityStep)
              {
               // --- SUA (theo yeu cau nguoi dung): CHI keo gian Step khi nen vua dong la nen
               //     BAT LOI (nguoc chieu chuoi) - Close < Open voi chuoi Buy, Close > Open voi
               //     chuoi Sell. Neu la nen THUAN chieu (VD nen xanh giat manh trong luc dang la
               //     chuoi Buy - nhip hoi ve bo) thi KHONG duoc nhan doi Step, tranh chuoi bo lo
               //     co hoi nhoi lenh don day/ha gia von dung luc gia dang hoi thuan loi.
               double openLive1  = iOpen(_Symbol, g_chartTF, 1);
               double closeLive1 = iClose(_Symbol, g_chartTF, 1);
               bool   adverseCandleLive = (direction == 1) ? (closeLive1 < openLive1) : (closeLive1 > openLive1);
               double atrPipsVelLive = GetDCA_ATRPips();
               double bodyPipsLive   = PriceToPips(MathAbs(closeLive1 - openLive1));
               if(adverseCandleLive && atrPipsVelLive > 0.0 && InpVelocityRatio > 0.0 && bodyPipsLive >= atrPipsVelLive * InpVelocityRatio)
                  stepLive = MathMax(stepLive, stepPips * InpVelocityRatio);
              }
            if(distPips < stepLive) { outReason = StringFormat("Chua du khoang cach (Gia song, %.1f/%.1f pip)", distPips, stepLive); return(false); }
            return(true);
           }

         if(!IsNewBarSince(g_chartTF, seq.lastOpenTime))
           { outReason = "Dang cho 1 nen (khung chart da chot) DONG ke tu lenh cuoi (InpRequireBarClose=true)"; return(false); } // Chua co nen nao DONG ke tu lenh cuoi

         double closePrice = iClose(_Symbol, g_chartTF, 1); // Gia DONG cua cay nen LIEN TRUOC (da hoan tat)
         if(closePrice <= 0.0) { outReason = "Khong doc duoc Gia dong nen (du lieu chua san sang)"; return(false); }
         if(!IsAdverseMove(seq, direction, closePrice)) { outReason = "Nen vua dong dang di THUAN chieu (chua bat loi theo Gia dong)"; return(false); }

         double rawCloseDistPips = MathAbs(PriceToPips(closePrice - seq.lastOpenPrice));
         double closeDistPips    = MathMax(0.0, rawCloseDistPips - curSpreadPips);

         // --- "DCA theo ATR" (Section 2.4b): San toi thieu (stepPips, VD 30 pip) LUON
         //     duoc giu - ATR chi NANG THEM khoang cach yeu cau len khi thi truong that
         //     su bien dong manh (ATR >= InpDCA_ATR_StormPips), giup EA tu dong "nhay xa
         //     hon moi nhoi" dung luc bao gia, thay vi mot con so pip co dinh duy nhat.
         double effStepPips = stepPips;
         if(InpDCA_UseATRDistance)
           {
            double atrPips = GetDCA_ATRPips();
            if(atrPips > 0.0 && InpDCA_ATR_StormPips > 0.0 && atrPips >= InpDCA_ATR_StormPips)
              {
               double atrStepPips = atrPips * InpDCA_ATR_Multiplier;
               if(atrStepPips > effStepPips)
                 {
                  PrintFormat("[Huuoaifx DCA] DCA-ATR (%s): Bien dong manh (ATR=%.1f pip >= nguong %.1f) -> nang khoang cach nhoi toi thieu %.1f -> %.1f pip.",
                              (direction == 1 ? "BUY" : "SELL"), atrPips, InpDCA_ATR_StormPips, stepPips, atrStepPips);
                  effStepPips = atrStepPips;
                 }
              }
           }
         // --- Candle Velocity Step (UPGRADE moi, Section 2.4b): neu THAN nen g_chartTF
         //     vua dong (shift 1) dai gap >= InpVelocityRatio lan ATR (nen "giat" qua nhanh -
         //     tin soc/bien dong dot bien), keo gian them khoang cach nhoi toi thieu len (nhan
         //     dung InpVelocityRatio - dung chung 1 Input lam ca Nguong VA He so nhan). Doc lap
         //     voi "DCA theo ATR" (InpDCA_UseATRDistance) o tren - lay MAX giua 2 co che.
         if(InpUseVelocityStep)
           {
            // --- SUA (theo yeu cau nguoi dung): CHI keo gian Step khi nen vua dong la nen BAT
            //     LOI (nguoc chieu chuoi) - Close < Open voi chuoi Buy, Close > Open voi chuoi
            //     Sell. Neu la nen THUAN chieu (VD nen xanh giat manh trong luc dang la chuoi Buy
            //     - nhip hoi ve bo) thi KHONG nhan doi Step, tranh bo lo co hoi nhoi don day/ha
            //     gia von dung luc gia dang hoi thuan loi.
            double openPrice1 = iOpen(_Symbol, g_chartTF, 1);
            bool   adverseCandle = (direction == 1) ? (closePrice < openPrice1) : (closePrice > openPrice1);
            double atrPipsVel = GetDCA_ATRPips();
            double bodyPips   = PriceToPips(MathAbs(closePrice - openPrice1));
            if(adverseCandle && atrPipsVel > 0.0 && InpVelocityRatio > 0.0 && bodyPips >= atrPipsVel * InpVelocityRatio)
              {
               double velStepPips = stepPips * InpVelocityRatio;
               if(velStepPips > effStepPips)
                 {
                  PrintFormat("[Huuoaifx DCA] Velocity Step (%s): Nen vua dong dai %.1f pip >= %.1f lan ATR (%.1f pip) -> nang khoang cach nhoi toi thieu len %.1f pip.",
                              (direction == 1 ? "BUY" : "SELL"), bodyPips, InpVelocityRatio, atrPipsVel, velStepPips);
                  effStepPips = velStepPips;
                 }
              }
           }

         if(closeDistPips < effStepPips) { outReason = StringFormat("Chua du khoang cach theo Gia dong nen (%.1f/%.1f pip)", closeDistPips, effStepPips); return(false); }

         // Xac nhan bo sung bang Gia HIEN TAI (song): tranh truong hop nen vua dong xac
         // nhan bat loi nhung ngay sau do Gia da hoi phuc nguoc lai qua nhanh.
         if(!IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia HIEN TAI (song) da hoi phuc nguoc lai, khong con bat loi nhu luc nen dong"; return(false); }

         return(true);
        }

      case Positive_Pyramiding:
        {
         // Chi nhoi khi gia dang di THUAN huong (co loi), nguoc voi DCA co dien
         if(IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang BAT LOI - Positive_Pyramiding chi nhoi khi gia THUAN chieu (co loi)"; return(false); }
         if(distPips < InpPyramidingStepPips) { outReason = StringFormat("Chua du khoang cach Pyramiding (%.1f/%.1f pip)", distPips, InpPyramidingStepPips); return(false); }
         if(InpPyramidingRequireSignal && !CheckDCASignal(direction)) { outReason = "Chua co Tin hieu DCA xac nhan (InpPyramidingRequireSignal=true)"; return(false); }
         return(true);
        }

      case Dual_Pyramiding:
        {
         // Nhoi ca 2 chieu doc lap - moi chuoi (Buy/Sell rieng) van ap dung
         // dung quy tac Positive Pyramiding cho chinh no (ham nay chi xu ly 1 chuoi).
         if(IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang BAT LOI - Dual_Pyramiding chi nhoi khi gia THUAN chieu (co loi)"; return(false); }
         if(distPips < InpPyramidingStepPips) { outReason = StringFormat("Chua du khoang cach Pyramiding (%.1f/%.1f pip)", distPips, InpPyramidingStepPips); return(false); }
         if(InpPyramidingRequireSignal && !CheckDCASignal(direction)) { outReason = "Chua co Tin hieu DCA xac nhan (InpPyramidingRequireSignal=true)"; return(false); }
         return(true);
        }

      case Dual_Signal_Pyramiding:
        {
         // Nhoi ca 2 chieu, BAT BUOC co tin hieu xac nhan (khong phu thuoc InpPyramidingRequireSignal)
         if(IsAdverseMove(seq, direction, currentPrice)) { outReason = "Gia dang BAT LOI - Dual_Signal_Pyramiding chi nhoi khi gia THUAN chieu (co loi)"; return(false); }
         if(distPips < InpPyramidingStepPips) { outReason = StringFormat("Chua du khoang cach Pyramiding (%.1f/%.1f pip)", distPips, InpPyramidingStepPips); return(false); }
         if(!CheckDCASignal(direction)) { outReason = "Chua co Tin hieu DCA xac nhan (Dual_Signal_Pyramiding luon can tin hieu)"; return(false); }
         return(true);
        }
     }

   outReason = "Khong khop kieu DCA nao (InpDCAMethod chua duoc xu ly - kiem tra lai cau hinh)";
   return(false);
  }

// ShouldOpenDCA: lop VO CONG KHAI cua ShouldOpenDCA_Core - sau khi Core dong y mo lenh,
// ap dung them 1 lop kiem tra CUOI CUNG: Chong don cuc gia (Section 2.4f, InpUseAntiCluster)
// dua tren gia DU KIEN se khop (currentPrice - Bid cho Buy / Ask cho Sell, sat voi gia
// thuc te se fill). Tach rieng lop nay de KHONG lam roi cau truc switch() ben trong Core.
// Tham so 'outReason' (moi, dung cho chan doan): sau khi ham tra ve, chua NGAN GON ly do
// tai sao CHUA mo lenh (hoac "OK" neu se mo) - dung de in Debug, KHONG anh huong logic that.
bool ShouldOpenDCA(const SSequenceState &seq, const int direction, const double currentPrice, string &outReason)
  {
   if(!ShouldOpenDCA_Core(seq, direction, currentPrice, outReason)) return(false);
   if(!PassesAntiClusterCheck(seq, currentPrice)) { outReason = "Bo loc Chong don cuc gia (Anti-Cluster) dang chan"; return(false); }
   outReason = "OK";
   return(true);
  }

//----------------------------------------------------------------------
// 9.4 GetLotIndexForNewOrder: chi so dung de tinh Lot cho lenh SAP MO, phu
//     thuoc InpLotBalancing (Independent: rieng tung chieu | Chain: ca 2 chieu dung chung)
//----------------------------------------------------------------------
int GetLotIndexForNewOrder(const int direction)
  {
   if(InpLotBalancing == Chain_Lots)
      return(g_buySeq.totalOrders + g_sellSeq.totalOrders);

   return(direction == 1 ? g_buySeq.totalOrders : g_sellSeq.totalOrders);
  }

//----------------------------------------------------------------------
// 9.5 CalculateDCALot: tinh khoi luong cho lenh o chi so 'lotIndex' (0 = lenh dau
//     tien cua chuoi/chain) theo InpLotMode, da Normalize theo Symbol.
//----------------------------------------------------------------------
// Tra ve He so nhan Lot ap dung cho 'lotIndex' khi InpUseLotMultiplierTiers=true, dua
// theo bang g_lotMultTierUpTo/g_lotMultTierValue (Section 2.4, 5 bac). Neu tat hoac
// chua co Tier hop le nao -> fallback ve InpLotMultiplier (giong GetDCAStepPips).
double GetLotMultiplierForIndex(const int lotIndex)
  {
   if(!InpUseLotMultiplierTiers || g_lotMultTierCount <= 0)
      return(InpLotMultiplier);

   int orderNumber = lotIndex + 1;
   for(int i = 0; i < g_lotMultTierCount; i++)
      if(orderNumber <= g_lotMultTierUpTo[i])
         return(g_lotMultTierValue[i]);

   return(g_lotMultTierValue[g_lotMultTierCount - 1]);
  }

double CalculateDCALot(const int lotIndex, const double multiplierOverride = 0.0, const double prevLot = 0.0)
  {
   double lot = InpInitialLot;
   double effMultiplier = (multiplierOverride > 0.0) ? multiplierOverride : GetLotMultiplierForIndex(lotIndex);

   switch(InpLotMode)
     {
      case Fixed_Lot:
         // LUON dung dung InpInitialLot cho MOI lenh (Entry lan DCA) - khong nhan he so,
         // khong cong don, khong doc chuoi tuy chinh. Day la CHE DO MAC DINH.
         lot = InpInitialLot;
         break;

      case Lot_Multiplier:
         lot = InpInitialLot * MathPow(effMultiplier, lotIndex);
         break;

      case Lot_Addition:
         lot = InpInitialLot + (InpLotAdditionStep * lotIndex);
         break;

      case Custom_Lot_Sequence:
         if(g_customLotCount <= 0)
            lot = InpInitialLot; // Fallback an toan neu chuoi rong/loi parse
         else if(lotIndex < g_customLotCount)
            lot = g_customLotSeq[lotIndex];
         else if(g_customLotCount2 > 0)
           {
            // Vuot qua do dai "1.He so thu cong" -> noi tiep sang "2.He so thu cong"
            int idx2 = lotIndex - g_customLotCount;
            lot = (idx2 < g_customLotCount2) ? g_customLotSeq2[idx2] : g_customLotSeq2[g_customLotCount2 - 1];
           }
         else
            // Khong co chuoi noi tiep -> giu nguyen gia tri CUOI CUNG cua chuoi 1,
            // khong tiep tuc suy dien de tranh khoi luong tang khong kiem soat.
            lot = g_customLotSeq[g_customLotCount - 1];

         // "Lots thu cong toi thieu bang lots lien truoc?" - khong cho Lot GIAM so
         // voi lenh truoc do trong cung chuoi (chi ap dung tu lenh DCA thu 2 tro di).
         if(InpCustomLotMinPrevious && prevLot > 0.0 && lot < prevLot)
            lot = prevLot;
         break;
     }

   return(NormalizeLotValue(lot));
  }

//----------------------------------------------------------------------
// 9.6 PARTIAL CLOSURE ENGINE - Kiem tra dieu kien va thuc hien cat bot lenh
//     xau nhat / chot loi mot phan khoi luong trong chuoi.
//     Ghi chu: viec dieu phoi THOI DIEM goi (cooldown, tan suat) se hoan
//     thien o Phan 3 (Risk Engine, chay tu OnTimer). Tai day cung cap san
//     ham KIEM TRA dieu kien va ham THUC THI de Phan 3 goi lai.
//----------------------------------------------------------------------
bool CheckPartialCloseCondition(const SSequenceState &seq)
  {
   if(!InpUsePartialClose)             return(false);
   if(!seq.active || seq.totalOrders <= 1) return(false); // Can >=2 lenh moi co y nghia "cat bot"
   return(seq.sequenceProfit >= InpPartialCloseTriggerMoney);
  }

// SUA LOI SAP XEP THEO PIPS (Fatal Bug #5): ham nay TRUOC DAY tim lenh "xau nhat" dua
// tren Floating Pips (PriceToPips), gay sai lech khi cac lenh trong chuoi co Lot KHAC
// NHAU (nhoi Lot lon hon Lot nho, hoac bi truot Swap/Commission khac nhau) - 1 lenh am
// it Pips nhung Lot rat lon co the dang LO NANG NHAT VE TIEN, trong khi 1 lenh am nhieu
// Pips nhung Lot nho lai duoc chon nham lam "nan nhan". Nay: tim lenh co seq.orders[i].profit
// (Tien, da tinh du Swap+Commission tu lan Sync gan nhat - xem Section 10.2) THAP NHAT
// (am sau nhat) - dung ban chat "xau nhat" theo dung so Tien dang mat, khong phu thuoc Lot.
int FindWorstOrderIndex(const SSequenceState &seq, const double currentPrice)
  {
   int    worstIdx   = -1;
   double worstMoney = 0.0;

   for(int i = 0; i < ArraySize(seq.orders); i++)
     {
      double moneyProfit = seq.orders[i].profit;
      if(worstIdx == -1 || moneyProfit < worstMoney)
        {
         worstMoney = moneyProfit;
         worstIdx   = i;
        }
     }
   return(worstIdx);
  }

// Thuc thi Partial Closure: neu InpCloseFurthestOrder=true -> dong han 1 lenh
// xau nhat (theo Tien). Nguoc lai -> dong lan luot cac lenh xau nhat (theo Tien,
// am sau nhat truoc) cho den khi tong khoi luong da dong >= InpPartialClosePercent%
// tong Lot chuoi.
bool ExecutePartialClosure(const SSequenceState &seq, const double currentPrice)
  {
   int n = ArraySize(seq.orders);
   if(n == 0) return(false);

   if(InpCloseFurthestOrder)
     {
      int idx = FindWorstOrderIndex(seq, currentPrice);
      if(idx < 0) return(false);
      ulong ticket = seq.orders[idx].ticket;

      if(!trade.PositionClose(ticket))
        {
         PrintFormat("[Huuoaifx DCA] Loi dong lenh xa nhat #%I64u: %d - %s",
                     ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
         return(false);
        }
      PrintFormat("[Huuoaifx DCA] Partial Closure: da dong lenh xa nhat #%I64u.", ticket);
      return(true);
     }

   double targetVolume = seq.totalLot * (InpPartialClosePercent / 100.0);
   double closedVolume = 0.0;

   // SUA LOI SAP XEP THEO PIPS (Fatal Bug #5): sap xep chi so theo Loi nhuan TIEN
   // (money[]) TANG DAN (am sau nhat / xau nhat truoc) THAY VI Floating Pips - dung
   // ban chat rui ro thuc te khi cac lenh co Lot khac nhau. So luong lenh trong 1 chuoi
   // Grid/DCA thuong khong lon nen dung Selection Sort la du nhanh.
   int    order[]; ArrayResize(order, n);
   double money[]; ArrayResize(money, n);
   for(int i = 0; i < n; i++)
     {
      order[i] = i;
      money[i] = seq.orders[i].profit;
     }
   for(int a = 0; a < n - 1; a++)
     {
      int minIdx = a;
      for(int b = a + 1; b < n; b++)
         if(money[order[b]] < money[order[minIdx]])
            minIdx = b;
      if(minIdx != a) { int tmp = order[a]; order[a] = order[minIdx]; order[minIdx] = tmp; }
     }

   bool anyClosed = false;
   for(int k = 0; k < n && closedVolume < targetVolume; k++)
     {
      int    idx    = order[k];
      ulong  ticket = seq.orders[idx].ticket;
      double vol    = seq.orders[idx].lot;
      double remain = targetVolume - closedVolume;

      if(vol <= remain + g_sym.volumeStep * 0.5)
        {
         if(trade.PositionClose(ticket))
           {
            closedVolume += vol;
            anyClosed = true;
           }
         else
            PrintFormat("[Huuoaifx DCA] Loi dong lenh #%I64u khi Partial Closure: %d - %s",
                        ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
      else
        {
         double partVol = NormalizeLotValue(remain);
         if(partVol >= g_sym.volumeMin && partVol < vol)
           {
            if(trade.PositionClosePartial(ticket, partVol))
              {
               closedVolume += partVol;
               anyClosed = true;
              }
            else
               PrintFormat("[Huuoaifx DCA] Loi dong 1 phan lenh #%I64u: %d - %s",
                           ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
           }
        }
     }

   if(anyClosed)
      PrintFormat("[Huuoaifx DCA] Partial Closure: da dong %.2f / muc tieu %.2f lot cua chuoi.", closedVolume, targetVolume);

   return(anyClosed);
  }

//----------------------------------------------------------------------
// 9.7 ADVANCED TRIM ENGINE (TIA LENH NANG CAO - CUNG CHUOI) - Khi chuoi da
//     du InpMinOrdersToTrim lenh, dung Loi nhuan cua lenh MOI NHAT de "tra"
//     cho lenh LO NANG NHAT trong chuoi:
//       - InpTrimUseNewestProfit = true : dong CA HAI lenh (moi nhat + lo
//         nang nhat) cung luc, chi khi tong P/L cua cap do >= 0.
//       - InpTrimUseNewestProfit = false: chi dong (hoac dong 1 phan theo
//         InpTrimClosePercent) khoi luong cua lenh LO NANG NHAT, giu lai
//         lenh moi nhat (dang lai) de tiep tuc chay.
//     Sau khi Tia thanh cong, chuoi chuyen sang che do "Post-Trim": TP moi
//     (xem EvaluatePostTrimTP) va He so nhan Lot moi (InpPostTrimLotMultiplier,
//     xem ProcessDCALogic) cho cac lenh DCA tiep theo.
//----------------------------------------------------------------------
int FindNewestOrderIndex(const SSequenceState &seq)
  {
   int      newestIdx  = -1;
   datetime newestTime = 0;
   for(int i = 0; i < ArraySize(seq.orders); i++)
      if(newestIdx == -1 || seq.orders[i].openTime >= newestTime)
        {
         newestTime = seq.orders[i].openTime;
         newestIdx  = i;
        }
   return(newestIdx);
  }

// Tim chi so lenh XAU NHAT nhung BO QUA (protect) InpTrimFirstOrdersNeeded lenh
// MO SOM NHAT trong chuoi (khong dung cac lenh dau lam "nan nhan" bi Tia).
int FindWorstOrderIndexProtectFirst(const SSequenceState &seq, const double currentPrice, const int protectFirstN)
  {
   int n = ArraySize(seq.orders);
   if(protectFirstN <= 0 || n <= protectFirstN) return(FindWorstOrderIndex(seq, currentPrice));

   // Sap xep chi so theo thoi gian mo tang dan de biet lenh nao la "dau" chuoi
   int order[]; ArrayResize(order, n);
   for(int i = 0; i < n; i++) order[i] = i;
   for(int a = 0; a < n - 1; a++)
     {
      int minIdx = a;
      for(int b = a + 1; b < n; b++)
         if(seq.orders[order[b]].openTime < seq.orders[order[minIdx]].openTime) minIdx = b;
      if(minIdx != a) { int tmp = order[a]; order[a] = order[minIdx]; order[minIdx] = tmp; }
     }

   int    worstIdx  = -1;
   double worstPips = 0.0;
   for(int k = protectFirstN; k < n; k++)
     {
      int idx = order[k];
      double floatingPips = PriceToPips((currentPrice - seq.orders[idx].openPrice) * seq.orders[idx].direction);
      if(worstIdx == -1 || floatingPips < worstPips) { worstPips = floatingPips; worstIdx = idx; }
     }
   return(worstIdx);
  }

// InpTrimIgnoreMagic=true: Tia lenh se KHONG chi gioi han trong cac lenh cua
// EA (seq.orders, da loc theo Magic/Comment) ma xet CA CAC LENH KHAC MAGIC
// cung Symbol + cung huong dang mo tren tai khoan (tru cac lenh co Tag dac
// biet Hedge/Hedging Zone/Equalizer/Nguoc chieu). Tra ve Ticket/Loi nhuan cua
// lenh XAU NHAT (bo qua protectFirstN lenh mo som nhat) tren toan bo Symbol.
bool FindWorstTicketAnyMagic(const int direction, const int protectFirstN, ulong &outTicket, double &outProfit, double &outLot)
  {
   ulong    tickets[]; datetime times[]; double profits[], lots[];
   double   curPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int posDir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(posDir != direction) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGEZONE_TAG) >= 0 || StringFind(cmt, HEDGE_TAG) >= 0 ||
         StringFind(cmt, EQUALIZER_TAG) >= 0 || StringFind(cmt, OPPOSITE_TAG) >= 0) continue;

      int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1); ArrayResize(times, n + 1); ArrayResize(profits, n + 1); ArrayResize(lots, n + 1);
      tickets[n] = ticket;
      times[n]   = (datetime)PositionGetInteger(POSITION_TIME);
      // UPGRADE (sua loi mat tien Hoa hong): POSITION_PROFIT khong bao gom phi san -
      // cong them POSITION_COMMISSION de Loi/Lo tinh dung 100% chi phi thuc te.
      profits[n] = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      lots[n]    = PositionGetDouble(POSITION_VOLUME);
     }

   int total = ArraySize(tickets);
   if(total == 0) { outTicket = 0; outProfit = 0.0; outLot = 0.0; return(false); }

   // Sap xep theo thoi gian mo tang dan de "bao ve" cac lenh mo som nhat
   int order[]; ArrayResize(order, total);
   for(int i = 0; i < total; i++) order[i] = i;
   for(int a = 0; a < total - 1; a++)
     {
      int minIdx = a;
      for(int b = a + 1; b < total; b++)
         if(times[order[b]] < times[order[minIdx]]) minIdx = b;
      if(minIdx != a) { int tmp = order[a]; order[a] = order[minIdx]; order[minIdx] = tmp; }
     }

   int start = (protectFirstN > 0 && total > protectFirstN) ? protectFirstN : 0;
   int worst = -1;
   for(int k = start; k < total; k++)
     {
      int idx = order[k];
      if(worst == -1 || profits[idx] < profits[order[worst]]) worst = k;
     }
   if(worst == -1) { outTicket = 0; outProfit = 0.0; outLot = 0.0; return(false); }

   int widx = order[worst];
   outTicket = tickets[widx];
   outProfit = profits[widx];
   outLot    = lots[widx];
   return(true);
  }

bool FindNewestTicketAnyMagic(const int direction, ulong &outTicket, double &outProfit)
  {
   datetime newestTime = 0; ulong newestTicket = 0; double newestProfit = 0.0; bool found = false;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int posDir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(posDir != direction) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGEZONE_TAG) >= 0 || StringFind(cmt, HEDGE_TAG) >= 0 ||
         StringFind(cmt, EQUALIZER_TAG) >= 0 || StringFind(cmt, OPPOSITE_TAG) >= 0) continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(!found || t >= newestTime)
        {
         newestTime = t; newestTicket = ticket;
         // UPGRADE (sua loi mat tien Hoa hong): cong them POSITION_COMMISSION.
         newestProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
         found = true;
        }
     }
   outTicket = newestTicket; outProfit = newestProfit;
   return(found);
  }

// Tim toi da maxCount lenh MOI NHAT (sap xep theo thoi gian mo GIAM DAN) trong
// chuoi de lam "von" ghep cap voi lenh Lo nang nhat (InpTrimLastOrdersMax - "So
// lenh cuoi toi da dung de tia"; 0/1 -> hanh vi cu la chi dung 1 lenh moi nhat).
int CollectNewestOrderTickets(const SSequenceState &seq, const int maxCount, ulong &outTickets[], double &outTotalProfit)
  {
   int n = ArraySize(seq.orders);
   int order[]; ArrayResize(order, n);
   for(int i = 0; i < n; i++) order[i] = i;
   for(int a = 0; a < n - 1; a++)
     {
      int maxIdx = a;
      for(int b = a + 1; b < n; b++)
         if(seq.orders[order[b]].openTime > seq.orders[order[maxIdx]].openTime) maxIdx = b;
      if(maxIdx != a) { int tmp = order[a]; order[a] = order[maxIdx]; order[maxIdx] = tmp; }
     }

   int take = MathMin(maxCount, n);
   ArrayResize(outTickets, take);
   outTotalProfit = 0.0;
   for(int i = 0; i < take; i++)
     {
      outTickets[i] = seq.orders[order[i]].ticket;
      outTotalProfit += seq.orders[order[i]].profit;
     }
   return(take);
  }

bool ProcessAdvancedTrim(SSequenceState &seq, const int direction, const double currentPrice)
  {
   if(!InpUseAdvancedTrim) return(false);
   if(!seq.active) return(false);
   if(seq.postTrimActive) return(false); // Dang cho TP moi cua lan Tia truoc -> chua Tia tiep

   // Lan Tia dau tien dung nguong InpMinOrdersToTrim, tu lan thu 2 tro di dung
   // nguong THAP HON InpTrimActivateFrom2nd (Tia duoc thuong xuyen hon).
   int trimThreshold = (seq.trimCount == 0) ? InpMinOrdersToTrim : InpTrimActivateFrom2nd;
   if(seq.totalOrders < trimThreshold) return(false);

   ulong  newestTicket, worstTicket;
   double newestProfit, worstProfit, worstVolAnyMagic = 0.0;
   ulong  newestTicketsPool[]; double newestPoolProfit = 0.0;
   bool   usePool = false;

   if(InpTrimIgnoreMagic)
     {
      // Xet CA CAC LENH KHAC MAGIC cung Symbol/huong (tru cac lenh Hedge/Equalizer/...)
      if(!FindNewestTicketAnyMagic(direction, newestTicket, newestProfit)) return(false);
      if(!FindWorstTicketAnyMagic(direction, InpTrimFirstOrdersNeeded, worstTicket, worstProfit, worstVolAnyMagic)) return(false);
      if(newestTicket == worstTicket) return(false);
     }
   else
     {
      int worstIdx = FindWorstOrderIndexProtectFirst(seq, currentPrice, InpTrimFirstOrdersNeeded);
      if(worstIdx < 0) return(false);
      worstTicket = seq.orders[worstIdx].ticket;
      worstProfit = seq.orders[worstIdx].profit;
      worstVolAnyMagic = seq.orders[worstIdx].lot;

      int maxNewest = (InpTrimLastOrdersMax > 0) ? InpTrimLastOrdersMax : 1;
      int got = CollectNewestOrderTickets(seq, maxNewest, newestTicketsPool, newestPoolProfit);
      if(got == 0) return(false);
      // Loai bo lenh Worst neu vo tinh lot vao pool Newest (chuoi qua nho)
      for(int i = 0; i < ArraySize(newestTicketsPool); i++)
         if(newestTicketsPool[i] == worstTicket) return(false);

      newestTicket = newestTicketsPool[0];
      newestProfit = newestPoolProfit;
      usePool = (ArraySize(newestTicketsPool) > 1);
     }

   if(newestProfit <= 0.0) return(false); // Chi Tia khi (cac) lenh moi nhat DANG CO LAI (tong)

   // Loi nhuan CON LAI sau khi Tia (worst+newest) phai dat toi thieu muc nay -
   // 0 -> khong yeu cau them (giu hanh vi cu, chi can >=0).
   double minAfter = (InpTrimProfitPercentAfter > 0.0)
                      ? (AccountInfoDouble(ACCOUNT_BALANCE) * InpTrimProfitPercentAfter / 100.0)
                      : InpTrimProfitMoneyAfter;

   if(InpTrimUseNewestProfit)
     {
      // SUA LOI TOAN HOC (yeu cau nguoi dung): truoc day dung MathMin(minAfter, 0.0) khien
      // dieu kien luon so sanh voi 0 (hoac am hon) khi minAfter duong, tuc la BO QUA han muc
      // Loi nhuan can co sau Tia (minAfter) - chi can Loi+Lo >= 0 la da Tia, sai voi y nghia
      // "% hoac So tien loi sau khi tia" cua InpTrimProfitPercentAfter/InpTrimProfitMoneyAfter.
      // Nay so sanh THANG voi minAfter (co the am neu nguoi dung co tinh de am) - dung ban chat.
      if((newestProfit + worstProfit) < minAfter) return(false); // Loi chua du "tra" het Lo + dat muc Loi nhuan sau Tia yeu cau

      bool ok1 = trade.PositionClose(worstTicket);
      bool ok2 = true;
      if(usePool)
        {
         for(int i = 0; i < ArraySize(newestTicketsPool); i++)
            if(!trade.PositionClose(newestTicketsPool[i])) ok2 = false;
        }
      else
         ok2 = trade.PositionClose(newestTicket);

      if(!ok1 || !ok2)
        {
         PrintFormat("[Huuoaifx DCA] Loi Tia lenh (%s) ghep cap #%I64u/#%I64u: %d - %s",
                     (direction == 1 ? "BUY" : "SELL"), worstTicket, newestTicket,
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
         SyncSequenceFromPositions();
         return(false);
        }
      PrintFormat("[Huuoaifx DCA] Tia lenh (%s): da dong Lenh Lo #%I64u (%.2f) + %d Lenh Lai gan nhat (%.2f), tong=%.2f.",
                  (direction == 1 ? "BUY" : "SELL"), worstTicket, worstProfit,
                  (usePool ? ArraySize(newestTicketsPool) : 1), newestProfit, worstProfit + newestProfit);
     }
   else
     {
      double closePct = MathMin(MathMax(InpTrimClosePercent, 0.0), 100.0);
      double worstVol = worstVolAnyMagic;
      double partVol  = NormalizeLotValue(worstVol * closePct / 100.0);

      bool ok;
      if(closePct >= 100.0 || partVol <= 0.0 || partVol >= worstVol)
         ok = trade.PositionClose(worstTicket);
      else if(partVol >= g_sym.volumeMin)
         ok = trade.PositionClosePartial(worstTicket, partVol);
      else
         return(false);

      if(!ok)
        {
         PrintFormat("[Huuoaifx DCA] Loi Tia mot phan lenh (%s) #%I64u: %d - %s",
                     (direction == 1 ? "BUY" : "SELL"), worstTicket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
         return(false);
        }
      PrintFormat("[Huuoaifx DCA] Tia lenh (%s): da dong %.0f%% khoi luong Lenh Lo nang nhat #%I64u (von tu Loi nhuan Lenh #%I64u=%.2f).",
                  (direction == 1 ? "BUY" : "SELL"), closePct, worstTicket, newestTicket, newestProfit);
     }

   seq.trimCount++;
   seq.postTrimActive = true;
   seq.partialTrimMode = false;
   SyncSequenceFromPositions();
   return(true);
  }

//----------------------------------------------------------------------
// 9.7b TIA LENH 1 PHAN (PARTIAL TRIM) - Co che Tia THAY THE, kich hoat khi
//      chuoi vua du InpPartialTrimActivateCount lenh VA dang am toi thieu
//      InpPartialTrimNegPercent% so voi Balance. Khac Advanced Trim (dong
//      HAN 1 cap lenh), Partial Trim chi dong 1 PHAN KHOI LUONG (theo
//      InpPartialTrimFirstLotPercent%) cua toi da InpPartialTrimLastOrdersMax
//      lenh xau nhat (0->Auto = 1 lenh), sau do chuyen sang Post-Trim TP
//      (dung chung EvaluatePostTrimTP/InpPostTrimTP_Pips voi Advanced Trim).
//----------------------------------------------------------------------
bool ProcessPartialTrim(SSequenceState &seq, const int direction, const double currentPrice)
  {
   if(!InpUsePartialTrim) return(false);
   if(!seq.active) return(false);
   if(seq.postTrimActive) return(false);
   if(seq.totalOrders < InpPartialTrimActivateCount) return(false);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return(false);
   double ddPercent = (seq.sequenceProfit / bal) * 100.0; // Am -> gia tri < 0
   if(ddPercent > InpPartialTrimNegPercent) return(false); // Chua du am (InpPartialTrimNegPercent la so am, vd -30)

   int maxOrders = (InpPartialTrimLastOrdersMax > 0) ? InpPartialTrimLastOrdersMax : 1;
   int n = ArraySize(seq.orders);

   // SUA LOI SAP XEP THEO PIPS (Fatal Bug #5): sap xep chi so theo Loi nhuan TIEN
   // (money[]) TANG DAN (am sau nhat / xau nhat truoc) THAY VI Floating Pips - de
   // chon dung lenh dang mat NHIEU TIEN NHAT lam nan nhan tia, khong phu thuoc Lot.
   int    order[]; ArrayResize(order, n);
   double money[]; ArrayResize(money, n);
   for(int i = 0; i < n; i++)
     {
      order[i] = i;
      money[i] = seq.orders[i].profit;
     }
   for(int a = 0; a < n - 1; a++)
     {
      int minIdx = a;
      for(int b = a + 1; b < n; b++)
         if(money[order[b]] < money[order[minIdx]]) minIdx = b;
      if(minIdx != a) { int tmp = order[a]; order[a] = order[minIdx]; order[minIdx] = tmp; }
     }

   double closePct = MathMin(MathMax(InpPartialTrimFirstLotPercent, 0.0), 100.0);
   bool anyClosed = false;
   int  closedCount = 0;
   for(int k = 0; k < n && closedCount < maxOrders; k++)
     {
      int    idx    = order[k];
      ulong  ticket = seq.orders[idx].ticket;
      double vol    = seq.orders[idx].lot;
      double partVol = NormalizeLotValue(vol * closePct / 100.0);

      bool ok;
      if(closePct >= 100.0 || partVol <= 0.0 || partVol >= vol)
         ok = trade.PositionClose(ticket);
      else if(partVol >= g_sym.volumeMin)
         ok = trade.PositionClosePartial(ticket, partVol);
      else
         continue;

      if(ok) { anyClosed = true; closedCount++; }
      else
         PrintFormat("[Huuoaifx DCA] Loi Tia 1 phan (%s) #%I64u: %d - %s",
                     (direction == 1 ? "BUY" : "SELL"), ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }

   if(!anyClosed) return(false);

   PrintFormat("[Huuoaifx DCA] Tia lenh 1 phan (%s): da tia %.0f%% khoi luong tren %d lenh xau nhat (Chuoi am %.1f%% Balance).",
               (direction == 1 ? "BUY" : "SELL"), closePct, closedCount, ddPercent);

   seq.trimCount++;
   seq.postTrimActive = true;
   seq.partialTrimMode = true;
   SyncSequenceFromPositions();
   return(true);
  }

// Sau khi Tia (postTrimActive=true), cho gia hoi ve InpPostTrimTP_Pips tinh tu
// Gia Trung Binh MOI (da tinh lai sau Tia) roi dong not toan bo phan con lai
// cua chuoi (co postTrimActive se duoc SyncSequenceFromPositions() tu dong
// dua ve false ngay khi chuoi tro thanh inactive). Neu lan Tia gan nhat la
// Tia lenh 1 phan (partialTrimMode=true), THEM dieu kien OR theo Tien/%
// (InpPartialTrimProfitPercentAfter/InpPartialTrimProfitMoneyAfter) - dat 1
// trong 2 dieu kien (Pips HOAC Tien/%) la du de dong not phan con lai.
void EvaluatePostTrimTP(SSequenceState &seq, const int direction)
  {
   if(!seq.postTrimActive) return;
   if(!seq.active) return;

   double curPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double target    = NormalizePriceValue(seq.avgPrice + direction * PipsToPrice(InpPostTrimTP_Pips));

   bool hit = (direction == 1) ? (curPrice >= target) : (curPrice <= target);

   if(!hit && seq.partialTrimMode)
     {
      double reqProfit = (InpPartialTrimProfitPercentAfter > 0.0)
                          ? (AccountInfoDouble(ACCOUNT_BALANCE) * InpPartialTrimProfitPercentAfter / 100.0)
                          : InpPartialTrimProfitMoneyAfter;
      if(reqProfit > 0.0 && seq.sequenceProfit >= reqProfit) hit = true;
     }

   // --- Bao ve Hedge nguoc chieu (Section 2.11, InpHedgeCloseMinProfit) - xem chi tiet
   //     tai HedgeCloseGuardBlocks(). Da hit Pips/Tien roi van CHUA dong neu chua du bu Hedge.
   if(hit && HedgeCloseGuardBlocks(seq, direction))
      hit = false;

   if(hit)
     {
      PrintFormat("[Huuoaifx DCA] Post-Trim TP (%s): dat muc tieu -> Dong not phan con lai cua chuoi (Gia=%s, Loi nhuan=%.2f).",
                  (direction == 1 ? "BUY" : "SELL"), DoubleToString(target, g_sym.digits), seq.sequenceProfit);
      CloseAllOrdersInSequence(seq);
      seq.recoveryCycle = 0;
      SyncSequenceFromPositions();
     }
  }

//----------------------------------------------------------------------
// 9.8 CROSS-SEQUENCE / ACCOUNT-LEVEL TRIM (TIA LENH LIEN CHUOI) - Dung Loi
//     nhuan cua CHUOI DOI DIEN (Buy<->Sell) va/hoac Loi nhuan DA CHOT trong
//     ngay (GetDailyRealizedProfit - Section 11.7) lam "von" de ho tro dong
//     lenh LO NANG NHAT cua chuoi dang am hon, khong phu thuoc chuoi do co
//     du so lenh toi thieu nhu Advanced Trim (9.7) hay khong.
//----------------------------------------------------------------------
void ProcessCrossSequenceTrim()
  {
   if(!InpUseCrossSequenceTrim) return;
   if(!g_buySeq.active && !g_sellSeq.active) return;

   bool needyIsBuy;
   if(!g_buySeq.active)       needyIsBuy = false;
   else if(!g_sellSeq.active) needyIsBuy = true;
   else                        needyIsBuy = (g_buySeq.sequenceProfit < g_sellSeq.sequenceProfit);

   int             dir         = needyIsBuy ? 1 : -1;
   SSequenceState  needySeq; // MQL5 khong ho tro toan tu ?: tren kieu struct -> dung if/else tuong minh
   if(needyIsBuy) needySeq = g_buySeq; else needySeq = g_sellSeq;
   if(!needySeq.active || needySeq.sequenceProfit >= 0.0) return; // Chi ho tro khi dang thuc su LO
   if(needySeq.totalOrders < InpCrossTrimActivateCount) return;   // Chua du So lenh kich hoat

   double oppositeProfit = needyIsBuy ? g_sellSeq.sequenceProfit : g_buySeq.sequenceProfit;
   double dailyProfit    = InpCrossTrimUseDailyProfit ? GetDailyRealizedProfit() : 0.0;

   double availableFund = 0.0;
   if(InpCrossTrimSourceMode == Opposite_Sequence)      availableFund = oppositeProfit;
   else if(InpCrossTrimSourceMode == Daily_Realized_Profit) availableFund = dailyProfit;
   else                                                  availableFund = oppositeProfit + dailyProfit; // Both

   availableFund -= MathAbs(InpCrossTrimMinReserve);
   if(availableFund <= 0.0) return;

   double curPrice = needyIsBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int maxOrders = (InpCrossTrimLastOrdersMax > 0) ? InpCrossTrimLastOrdersMax : 1;
   int closedCount = 0;

   while(closedCount < maxOrders)
     {
      ulong  worstTicket; double worstProfit; double worstLot;
      bool   found;
      if(InpCrossTrimFilterMagicPair)
        {
         SSequenceState curSeq;
         if(needyIsBuy) curSeq = g_buySeq; else curSeq = g_sellSeq;
         int idx = FindWorstOrderIndexProtectFirst(curSeq, curPrice, InpCrossTrimFirstOrdersNeeded);
         found = (idx >= 0);
         if(found) { worstTicket = curSeq.orders[idx].ticket; worstProfit = curSeq.orders[idx].profit; worstLot = curSeq.orders[idx].lot; }
         else      { worstTicket = 0; worstProfit = 0.0; worstLot = 0.0; }
        }
      else
         found = FindWorstTicketAnyMagic(dir, InpCrossTrimFirstOrdersNeeded, worstTicket, worstProfit, worstLot);

      if(!found || worstProfit >= 0.0) break;

      // Yeu cau von du de dong HET lenh nay CONG THEM khoan du phong InpCrossTrimProfitAfter
      double needed = MathAbs(worstProfit) + MathMax(InpCrossTrimProfitAfter, 0.0);

      if(availableFund >= needed)
        {
         if(!trade.PositionClose(worstTicket))
           {
            PrintFormat("[Huuoaifx DCA] Loi Cross-Sequence Trim khi dong lenh #%I64u: %d - %s",
                        worstTicket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
            break;
           }
         PrintFormat("[Huuoaifx DCA] Cross-Sequence Trim: dung von ho tro %.2f (Doi dien=%.2f, Realized ngay=%.2f) de dong Lenh Lo #%I64u (%.2f) cua chuoi %s.",
                     availableFund, oppositeProfit, dailyProfit, worstTicket, worstProfit, (dir == 1 ? "BUY" : "SELL"));
         availableFund -= MathAbs(worstProfit);
         closedCount++;
         SyncSequenceFromPositions();
        }
      else if(InpCrossTrimUsePartialSameDir && worstLot >= InpCrossTrimPartialMinLot && availableFund > 0.0)
        {
         // Von khong du dong het - tia 1 PHAN khoi luong cua chinh lenh lo nang nhat nay (cung chieu voi chuoi can)
         double partVol = NormalizeLotValue(worstLot * InpCrossTrimPartialPercent / 100.0);
         if(partVol >= g_sym.volumeMin && partVol < worstLot)
           {
            if(trade.PositionClosePartial(worstTicket, partVol))
              {
               PrintFormat("[Huuoaifx DCA] Cross-Sequence Trim (1 phan): dong %.0f%% khoi luong Lenh Lo #%I64u bang von ho tro %.2f.",
                           InpCrossTrimPartialPercent, worstTicket, availableFund);
               SyncSequenceFromPositions();
              }
           }
         break;
        }
      else
         break;
     }
  }

//======================================================================
// 10. DONG BO TRANG THAI (POSITION SYNC) - Nguon du lieu DUY NHAT cho
//     g_buySeq / g_sellSeq / g_hedge, doc truc tiep tu Position that su
//     tren Terminal. Goi o dau OnTick()/OnTimer() truoc khi ra quyet dinh.
//======================================================================

// --- 10.1 Danh sach Virtual SL/TP: tra cuu / cap nhat / don dep theo Ticket
bool GetVirtualLevels(const ulong ticket, double &sl, double &tp)
  {
   for(int i = 0; i < ArraySize(g_vLevels); i++)
      if(g_vLevels[i].ticket == ticket)
        {
         sl = g_vLevels[i].sl;
         tp = g_vLevels[i].tp;
         return(true);
        }
   sl = 0.0; tp = 0.0;
   return(false);
  }

void SetVirtualLevels(const ulong ticket, const double sl, const double tp)
  {
   for(int i = 0; i < ArraySize(g_vLevels); i++)
      if(g_vLevels[i].ticket == ticket)
        {
         g_vLevels[i].sl = sl;
         g_vLevels[i].tp = tp;
         return;
        }
   int n = ArraySize(g_vLevels);
   ArrayResize(g_vLevels, n + 1);
   g_vLevels[n].ticket = ticket;
   g_vLevels[n].sl = sl;
   g_vLevels[n].tp = tp;
  }

void PruneVirtualLevels(const ulong &liveTickets[])
  {
   SVirtualLevel kept[];
   for(int i = 0; i < ArraySize(g_vLevels); i++)
     {
      bool found = false;
      for(int j = 0; j < ArraySize(liveTickets); j++)
         if(liveTickets[j] == g_vLevels[i].ticket) { found = true; break; }
      if(found)
        {
         int n = ArraySize(kept);
         ArrayResize(kept, n + 1);
         kept[n] = g_vLevels[i];
        }
     }
   ArrayFree(g_vLevels);
   ArrayResize(g_vLevels, ArraySize(kept));
   for(int i = 0; i < ArraySize(kept); i++)
      g_vLevels[i] = kept[i];
  }

// --- 10.2 Doc toan bo Position (Symbol + Magic hien tai) va DUNG LAI TOAN BO
//          g_buySeq / g_sellSeq / g_hedge tu du lieu that. Cac truong META
//          (recoveryCycle/lastSLTime/peakProfit) duoc GIU NGUYEN qua moi lan
//          dong bo vi khong the suy ra duoc tu danh sach Position dang mo.
void SyncSequenceFromPositions()
  {
   int      buyRecoveryCycle  = g_buySeq.recoveryCycle;
   datetime buyLastSL         = g_buySeq.lastSLTime;
   double   buyPeak           = g_buySeq.peakProfit;
   datetime buyPeakTime       = g_buySeq.peakProfitTime;
   double   buyTrail          = g_buySeq.trailingStopPrice;
   int      buyTrimCount      = g_buySeq.trimCount;
   bool     buyPostTrim       = g_buySeq.postTrimActive;
   bool     buyPartialTrim    = g_buySeq.partialTrimMode;
   bool     buyEmergency      = g_buySeq.emergencyActive;
   datetime buyLastClose      = g_buySeq.lastCloseTime;
   int      buyLotteryStage   = g_buySeq.lotteryStage;
   bool     buyManualReset    = g_buySeq.manualResetActive;
   bool     wasBuyActive      = g_buySeq.active;
   double   oldBuyProfit      = g_buySeq.sequenceProfit;
   int      sellRecoveryCycle = g_sellSeq.recoveryCycle;
   datetime sellLastSL        = g_sellSeq.lastSLTime;
   double   sellPeak          = g_sellSeq.peakProfit;
   datetime sellPeakTime      = g_sellSeq.peakProfitTime;
   double   sellTrail         = g_sellSeq.trailingStopPrice;
   int      sellTrimCount     = g_sellSeq.trimCount;
   bool     sellPostTrim      = g_sellSeq.postTrimActive;
   bool     sellPartialTrim   = g_sellSeq.partialTrimMode;
   bool     sellEmergency     = g_sellSeq.emergencyActive;
   datetime sellLastClose     = g_sellSeq.lastCloseTime;
   int      sellLotteryStage  = g_sellSeq.lotteryStage;
   bool     sellManualReset   = g_sellSeq.manualResetActive;
   bool     wasSellActive     = g_sellSeq.active;
   double   oldSellProfit     = g_sellSeq.sequenceProfit;

   ResetSequenceState(g_buySeq);
   ResetSequenceState(g_sellSeq);
   g_buySeq.recoveryCycle  = buyRecoveryCycle;  g_buySeq.lastSLTime  = buyLastSL;  g_buySeq.peakProfit  = buyPeak;  g_buySeq.peakProfitTime  = buyPeakTime;  g_buySeq.trailingStopPrice  = buyTrail;
   g_buySeq.trimCount = buyTrimCount; g_buySeq.postTrimActive = buyPostTrim; g_buySeq.partialTrimMode = buyPartialTrim; g_buySeq.emergencyActive = buyEmergency;
   g_buySeq.lastCloseTime = buyLastClose; g_buySeq.lotteryStage = buyLotteryStage; g_buySeq.manualResetActive = buyManualReset;
   g_sellSeq.recoveryCycle = sellRecoveryCycle; g_sellSeq.lastSLTime = sellLastSL; g_sellSeq.peakProfit = sellPeak; g_sellSeq.peakProfitTime = sellPeakTime; g_sellSeq.trailingStopPrice = sellTrail;
   g_sellSeq.trimCount = sellTrimCount; g_sellSeq.postTrimActive = sellPostTrim; g_sellSeq.partialTrimMode = sellPartialTrim; g_sellSeq.emergencyActive = sellEmergency;
   g_sellSeq.lastCloseTime = sellLastClose; g_sellSeq.lotteryStage = sellLotteryStage; g_sellSeq.manualResetActive = sellManualReset;

   g_hedge.active = false; g_hedge.ticket = 0; g_hedge.direction = 0;
   g_hedge.lot = 0.0; g_hedge.openPrice = 0.0; g_hedge.openTime = 0;

   g_equalizer.active = false; g_equalizer.ticket = 0; g_equalizer.direction = 0; g_equalizer.lot = 0.0;

   g_hedgeZone.active = false; g_hedgeZone.ticket = 0; g_hedgeZone.direction = 0; g_hedgeZone.lot = 0.0; g_hedgeZone.openPrice = 0.0;
   g_oppBuy.active  = false; g_oppBuy.ticket  = 0; g_oppBuy.direction  = 0; g_oppBuy.lot  = 0.0;
   g_oppSell.active = false; g_oppSell.ticket = 0; g_oppSell.direction = 0; g_oppSell.lot = 0.0;

   int total = PositionsTotal();
   ulong liveTickets[];
   ArrayResize(liveTickets, total);
   int liveCount = 0;

   double buySumPV = 0.0, sellSumPV = 0.0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i); // Da tu dong "chon" Position nay cho cac PositionGetXXX() ben duoi
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsManagedPosition((long)PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_COMMENT))) continue;

      liveTickets[liveCount] = ticket; liveCount++;

      long     posType = PositionGetInteger(POSITION_TYPE);
      int      dir      = (posType == POSITION_TYPE_BUY) ? 1 : -1;
      double   lot       = PositionGetDouble(POSITION_VOLUME);
      double   openPr    = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime openTm    = (datetime)PositionGetInteger(POSITION_TIME);
      // UPGRADE (sua loi mat tien Hoa hong): POSITION_PROFIT khong bao gom phi san (Commission)
      // - cong them POSITION_COMMISSION de Loi nhuan cua chuoi (sequenceProfit) va tung lenh
      // (SGridOrder.profit) phan anh DUNG 100% ket qua thuc te (anh huong day chuyen den moi
      // noi dung sequenceProfit: EvaluateChainTP/StepProfit/Trailing/AccountTargets/Trend Switch...).
      double   profit    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      string   cmt       = PositionGetString(POSITION_COMMENT);

      // Luu y: kiem tra HEDGEZONE_TAG TRUOC HEDGE_TAG vi " #HEDGEZONE" CHUA " #HEDGE"
      // nhu 1 chuoi con - neu kiem tra nguoc lai se nhan nham lenh Hedging Zone thanh Hedging.
      if(StringFind(cmt, HEDGEZONE_TAG) >= 0)
        {
         g_hedgeZone.active = true; g_hedgeZone.ticket = ticket; g_hedgeZone.direction = dir;
         g_hedgeZone.lot = lot; g_hedgeZone.openPrice = openPr;
         continue; // Lenh Hedging Zone KHONG tinh vao chuoi Buy/Sell thong thuong
        }

      if(StringFind(cmt, HEDGE_TAG) >= 0)
        {
         g_hedge.active = true; g_hedge.ticket = ticket; g_hedge.direction = dir;
         g_hedge.lot = lot; g_hedge.openPrice = openPr; g_hedge.openTime = openTm;
         continue; // Lenh Hedge KHONG tinh vao chuoi Buy/Sell thong thuong
        }

      if(StringFind(cmt, EQUALIZER_TAG) >= 0)
        {
         g_equalizer.active = true; g_equalizer.ticket = ticket; g_equalizer.direction = dir; g_equalizer.lot = lot;
         continue; // Lenh Can bang Lot KHONG tinh vao chuoi Buy/Sell thong thuong
        }

      if(StringFind(cmt, OPPOSITE_TAG) >= 0)
        {
         // Lenh Mo Nguoc Chieu huong SELL (dir=-1) la doi voi chuoi BUY, va nguoc lai.
         if(dir == -1) { g_oppBuy.active  = true; g_oppBuy.ticket  = ticket; g_oppBuy.direction  = dir; g_oppBuy.lot  = lot; }
         else           { g_oppSell.active = true; g_oppSell.ticket = ticket; g_oppSell.direction = dir; g_oppSell.lot = lot; }
         continue; // Lenh Mo Nguoc Chieu KHONG tinh vao chuoi Buy/Sell thong thuong
        }

      SGridOrder o;
      o.ticket = ticket; o.direction = dir; o.lot = lot; o.openPrice = openPr; o.openTime = openTm; o.profit = profit;
      double vsl = 0.0, vtp = 0.0;
      bool   hasV = GetVirtualLevels(ticket, vsl, vtp);
      o.virtualSL = vsl; o.virtualTP = vtp; o.virtualActive = (hasV && InpUseVirtualTPSL);

      if(dir == 1)
        {
         int n = ArraySize(g_buySeq.orders);
         ArrayResize(g_buySeq.orders, n + 1);
         g_buySeq.orders[n] = o;
         g_buySeq.totalOrders++; g_buySeq.totalLot += lot; buySumPV += openPr * lot;
         g_buySeq.sequenceProfit += profit;
         if(g_buySeq.lastOpenTime == 0 || openTm > g_buySeq.lastOpenTime)
           { g_buySeq.lastOpenTime = openTm; g_buySeq.lastOpenPrice = openPr; }
        }
      else
        {
         int n = ArraySize(g_sellSeq.orders);
         ArrayResize(g_sellSeq.orders, n + 1);
         g_sellSeq.orders[n] = o;
         g_sellSeq.totalOrders++; g_sellSeq.totalLot += lot; sellSumPV += openPr * lot;
         g_sellSeq.sequenceProfit += profit;
         if(g_sellSeq.lastOpenTime == 0 || openTm > g_sellSeq.lastOpenTime)
           { g_sellSeq.lastOpenTime = openTm; g_sellSeq.lastOpenPrice = openPr; }
        }
     }

   if(g_buySeq.totalLot > 0.0)  g_buySeq.avgPrice  = NormalizePriceValue(buySumPV / g_buySeq.totalLot);
   if(g_sellSeq.totalLot > 0.0) g_sellSeq.avgPrice = NormalizePriceValue(sellSumPV / g_sellSeq.totalLot);

   g_buySeq.active  = (g_buySeq.totalOrders > 0);
   g_sellSeq.active = (g_sellSeq.totalOrders > 0);

   if(g_buySeq.sequenceProfit  > g_buySeq.peakProfit)  { g_buySeq.peakProfit  = g_buySeq.sequenceProfit;  g_buySeq.peakProfitTime  = TimeCurrent(); }
   if(g_sellSeq.sequenceProfit > g_sellSeq.peakProfit) { g_sellSeq.peakProfit = g_sellSeq.sequenceProfit; g_sellSeq.peakProfitTime = TimeCurrent(); }
   if(!g_buySeq.active)
     {
      // Chuoi da dong het -> Reset toan bo trang thai "chu ky" cho lan mo chuoi tiep theo
      g_buySeq.peakProfit = 0.0; g_buySeq.peakProfitTime = 0; g_buySeq.trailingStopPrice = 0.0;
      g_buySeq.trimCount = 0; g_buySeq.postTrimActive = false; g_buySeq.partialTrimMode = false; g_buySeq.emergencyActive = false;
      g_buySeq.manualResetActive = false;
      if(wasBuyActive)
        {
         // Chuoi VUA dong het ngay trong lan Sync nay -> ghi nhan moc thoi gian (dung cho
         // Delay sau khi clear lenh / Delay sau SL-TP Xo So) va cap nhat Xo So Stage.
         g_buySeq.lastCloseTime = TimeCurrent();
         if(InpEnableLotteryMode)
            g_buySeq.lotteryStage = (oldBuyProfit < 0.0) ? (buyLotteryStage + 1) : 0;
        }
     }
   if(!g_sellSeq.active)
     {
      g_sellSeq.peakProfit = 0.0; g_sellSeq.peakProfitTime = 0; g_sellSeq.trailingStopPrice = 0.0;
      g_sellSeq.trimCount = 0; g_sellSeq.postTrimActive = false; g_sellSeq.partialTrimMode = false; g_sellSeq.emergencyActive = false;
      g_sellSeq.manualResetActive = false;
      if(wasSellActive)
        {
         g_sellSeq.lastCloseTime = TimeCurrent();
         if(InpEnableLotteryMode)
            g_sellSeq.lotteryStage = (oldSellProfit < 0.0) ? (sellLotteryStage + 1) : 0;
        }
     }

   ArrayResize(liveTickets, liveCount);
   PruneVirtualLevels(liveTickets);
  }

//----------------------------------------------------------------------
// 10.3 Cac ham dong lenh dung chung (Risk Engine / Grid Engine deu goi)
//----------------------------------------------------------------------
void CloseAllOrdersInSequence(const SSequenceState &seq)
  {
   int chainDir = 0;
   if(ArraySize(seq.orders) > 0) chainDir = seq.orders[0].direction;

   // --- UPGRADE (do bo an toan): dong tung lenh voi RETRY toi da 3 lan (RefreshRates()
   //     roi thu dong lai) khi gap loi co the tu phuc hoi duoc (Requote/Gia thay
   //     doi/Timeout) - tranh truong hop 1 lenh "sot lai" chi vi 1 lan bao gia lech tuc
   //     thoi, dac biet de gap hon khi dong CA CHUOI nhieu lenh lien tiep so voi dong 1
   //     lenh le. Sau khi dong xong, kiem tra lai SO LENH THUC TE CON LAI truoc khi in
   //     canh bao - viec dong bo lai trang thai chuoi (seq.active/orders...) van do
   //     SyncSequenceFromPositions() dam nhiem ngay sau khi ham nay tra ve (nguon du
   //     lieu duy nhat = vi the thuc te tren san, khong tu suy doan).
   int unclosedCount = 0;
   for(int i = 0; i < ArraySize(seq.orders); i++)
     {
      ulong ticket = seq.orders[i].ticket;
      bool  closed = false;
      for(int attempt = 1; attempt <= 3 && !closed; attempt++)
        {
         if(!PositionSelectByTicket(ticket)) { closed = true; break; } // Da khong con Position nay (VD da tu dong dong) -> coi nhu xong
         closed = trade.PositionClose(ticket);
         if(!closed)
           {
            uint rc = trade.ResultRetcode();
            bool retryable = (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
                              rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT);
            PrintFormat("[Huuoaifx DCA] Loi dong lenh #%I64u (lan %d/3): %d - %s%s",
                        ticket, attempt, rc, trade.ResultRetcodeDescription(),
                        (retryable && attempt < 3) ? " -> Refresh gia va thu lai." : "");
            if(!retryable) break; // Loi khac (VD Position khong ton tai/da dong) -> retry vo ich
            if(attempt < 3) symbolInfo.RefreshRates();
           }
        }
      if(!closed) unclosedCount++;
     }
   if(unclosedCount > 0)
      PrintFormat("[Huuoaifx DCA] CANH BAO: Con %d lenh CHUA dong duoc sau 3 lan thu - se duoc kiem tra/dong bo lai o lan cap nhat trang thai tiep theo (SyncSequenceFromPositions).", unclosedCount);

   // AN TOAN (da sua lai dung theo nguoi dung chi ra): lenh Hedge (Section 11.3) mo CUNG
   // CHIEU voi chuoi dang THANG THE de tang toc, tuc la NGUOC CHIEU voi chinh chuoi con
   // lai (chuoi yeu hon tai thoi diem kich hoat). Khi 1 chuoi dong (vi bat ky ly do gi - TP,
   // SL, Step Profit, Trend Switch...), lenh Hedge NGUOC CHIEU voi chuoi do (neu co) cung
   // da toi luc "chot so" cung - vi no thuong bien dong NGHICH voi chinh chuoi vua dong,
   // dong LUON de tranh de no o lai mot minh (thuong Lot lon, de mac o vung gia cuc tri).
   if(g_hedge.active && chainDir != 0 && g_hedge.direction == -chainDir)
     {
      double hedgeProfit = GetHedgeProfit();
      if(trade.PositionClose(g_hedge.ticket))
         PrintFormat("[Huuoaifx DCA] Hedge (nguoc chieu voi chuoi vua dong): da dong lenh Hedge #%I64u, Profit=%.2f.",
                     g_hedge.ticket, hedgeProfit);
      else
         PrintFormat("[Huuoaifx DCA] Loi dong lenh Hedge #%I64u: %d - %s",
                     g_hedge.ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
  }

// SUA LOI THIEU RETRY KHI DONG TOAN BO (Fatal Bug #5): TRUOC DAY ham nay chi goi
// trade.PositionClose(ticket) DUY NHAT 1 LAN cho moi Position - neu gap loi tam thoi co
// the tu phuc hoi (Requote/Gia thay doi/Timeout, rat de gap khi Vang XAUUSD dang giat manh
// luc Dong toan bo EA - VD Money TP All/SL All/Total TP Hedge), lenh do se "sot lai" KHONG
// duoc dong, trai voi dung y nghia "Dong TOAN BO" cua ham. Nay: ap dung CUNG CO CHE RETRY
// toi da 3 lan (RefreshRates() roi thu dong lai) giong het CloseAllOrdersInSequence() o
// tren, dam bao dong bo hanh vi retry giua 2 ham dong lenh chinh cua EA.
void CloseAllEAOrders()
  {
   int unclosedCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsManagedPosition((long)PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_COMMENT))) continue;

      bool closed = false;
      for(int attempt = 1; attempt <= 3 && !closed; attempt++)
        {
         if(!PositionSelectByTicket(ticket)) { closed = true; break; } // Da khong con Position nay -> coi nhu xong
         closed = trade.PositionClose(ticket);
         if(!closed)
           {
            uint rc = trade.ResultRetcode();
            bool retryable = (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
                              rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT);
            PrintFormat("[Huuoaifx DCA] CloseAllEAOrders: Loi dong lenh #%I64u (lan %d/3): %d - %s%s",
                        ticket, attempt, rc, trade.ResultRetcodeDescription(),
                        (retryable && attempt < 3) ? " -> Refresh gia va thu lai." : "");
            if(!retryable) break; // Loi khac (VD Position khong ton tai/da dong) -> retry vo ich
            if(attempt < 3) symbolInfo.RefreshRates();
           }
        }
      if(!closed) unclosedCount++;
     }
   if(unclosedCount > 0)
      PrintFormat("[Huuoaifx DCA] CANH BAO (CloseAllEAOrders): Con %d lenh CHUA dong duoc sau 3 lan thu - se duoc kiem tra/dong bo lai o lan cap nhat trang thai tiep theo.", unclosedCount);
  }

//======================================================================
// 11. RISK ENGINE - Virtual TP/SL, Martingale SL Recovery, Hedging Zone,
//     Target Profit/Risk (Account/Buy/Sell + Step Ladder), Time Filter.
//======================================================================

//----------------------------------------------------------------------
// 11.1 VIRTUAL TP/SL MANAGEMENT - Theo doi va tu dong dong lenh khi gia
//      cham muc TP/SL AN (khong gui len Broker). Goi tu OnTimer().
//----------------------------------------------------------------------
void ManageVirtualTPSL()
  {
   if(!InpUseVirtualTPSL) return;
   if(ArraySize(g_vLevels) == 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsManagedPosition((long)PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_COMMENT))) continue;

      double sl = 0.0, tp = 0.0;
      if(!GetVirtualLevels(ticket, sl, tp)) continue;

      long   posType  = PositionGetInteger(POSITION_TYPE);
      int    dir       = (posType == POSITION_TYPE_BUY) ? 1 : -1;
      double curPrice  = (dir == 1) ? bid : ask;

      bool hitSL = (sl > 0.0) && ((dir == 1 && curPrice <= sl) || (dir == -1 && curPrice >= sl));
      bool hitTP = (tp > 0.0) && ((dir == 1 && curPrice >= tp) || (dir == -1 && curPrice <= tp));

      if(hitSL || hitTP)
        {
         if(trade.PositionClose(ticket))
            PrintFormat("[Huuoaifx DCA] Virtual %s: da dong lenh #%I64u tai gia %s",
                        (hitTP ? "TP" : "SL"), ticket, DoubleToString(curPrice, g_sym.digits));
         else
            PrintFormat("[Huuoaifx DCA] Loi dong lenh Virtual TP/SL #%I64u: %d - %s",
                        ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
  }

//----------------------------------------------------------------------
// 11.2 MARTINGALE SL RECOVERY - Cat lo chu dong ca chuoi khi floating loss
//      cham InpSLRecoveryMoney, ghi nhan chu ky va thoi diem de EA tu vao
//      lai (voi Lot nhan he so InpSLRecoveryLotMultiplier) sau thoi gian Delay.
//----------------------------------------------------------------------
void ProcessSLRecovery(SSequenceState &seq, const int direction)
  {
   if(!InpUseSLRecovery) return;
   if(!seq.active) return;
   if(seq.recoveryCycle >= InpSLRecoveryMaxCycles) return;
   if(seq.sequenceProfit > -MathAbs(InpSLRecoveryMoney)) return;

   CloseAllOrdersInSequence(seq);
   seq.recoveryCycle++;
   seq.lastSLTime = TimeCurrent();
   PrintFormat("[Huuoaifx DCA] SL Recovery: cat lo chuoi %s tai %.2f (Chu ky %d/%d) - cho %d giay truoc khi vao lai.",
               (direction == 1 ? "BUY" : "SELL"), seq.sequenceProfit, seq.recoveryCycle, InpSLRecoveryMaxCycles, InpSLRecoveryDelaySec);
  }

// Kiem tra 1 chieu (Buy/Sell) co duoc phep MO CHUOI MOI ngay bay gio khong,
// xet theo trang thai Martingale SL Recovery (delay + gioi han chu ky).
bool CanStartNewSequenceNow(const int direction)
  {
   SSequenceState seq; // MQL5 khong ho tro toan tu ?: tren kieu struct -> dung if/else tuong minh
   if(direction == 1) seq = g_buySeq; else seq = g_sellSeq;

   // --- So phut delay sau khi clear lenh (Section 2.1) - ap dung chung cho MOI
   //     lan chuoi vua dong het, khong rieng gi truong hop SL Recovery.
   if(InpClearOrderDelayMin > 0 && seq.lastCloseTime > 0)
      if((TimeCurrent() - seq.lastCloseTime) < InpClearOrderDelayMin * 60) return(false);

   // --- Che do Xo So: Delay rieng sau khi 1 chuoi vua dong (SL hoac TP) truoc khi
   //     cho phep mo chuoi moi (Section 2.3).
   if(InpEnableLotteryMode && InpLotteryDelayAfterSLTP_Min > 0 && seq.lastCloseTime > 0)
      if((TimeCurrent() - seq.lastCloseTime) < InpLotteryDelayAfterSLTP_Min * 60) return(false);

   if(!InpUseSLRecovery) return(true);

   if(seq.lastSLTime <= 0) return(true);
   if(seq.recoveryCycle >= InpSLRecoveryMaxCycles) return(false); // Da cham gioi han an toan - dung han chieu nay
   return((TimeCurrent() - seq.lastSLTime) >= InpSLRecoveryDelaySec);
  }

//----------------------------------------------------------------------
// 11.2b DONG LENH KHI TIN HIEU DAO CHIEU (TREND REVERSAL) - Khi dang co 1
//       chuoi chay theo huong A nhung InpEntrySignal (da qua toan bo cac Bo
//       loc MACD/EMA neu bat) xac nhan huong doi dien B, EA chot toan bo
//       chuoi A ngay lap tuc de nhuong cho chuoi B moi mo (o Section 14.4).
//----------------------------------------------------------------------
void CheckTrendReversalClose()
  {
   if(!InpCloseOnTrendReversal) return;

   if(g_buySeq.active && IsSignalConfirmed(InpEntrySignal, -1))
     {
      PrintFormat("[Huuoaifx DCA] Trend Reversal: tin hieu doi chieu SELL xuat hien -> dong toan bo chuoi BUY dang chay.");
      CloseAllOrdersInSequence(g_buySeq);
      g_buySeq.recoveryCycle = 0;
      SyncSequenceFromPositions();
     }

   if(g_sellSeq.active && IsSignalConfirmed(InpEntrySignal, 1))
     {
      PrintFormat("[Huuoaifx DCA] Trend Reversal: tin hieu doi chieu BUY xuat hien -> dong toan bo chuoi SELL dang chay.");
      CloseAllOrdersInSequence(g_sellSeq);
      g_sellSeq.recoveryCycle = 0;
      SyncSequenceFromPositions();
     }
  }

//----------------------------------------------------------------------
// 9.2c TREND SWITCH - "Dong bang" chieu dang lo khi thi truong dao chieu manh,
//      dong thoi mo/nhoi chieu con lai THUAN xu huong (nhu 1 chuoi Pyramiding
//      duong) de vua kiem loi vua lam hedge cho tai khoan; khi tin hieu dao
//      chieu tro lai (hoac ADX yeu di = thi truong on dinh), chot toan bo chuoi
//      "duoi xu huong" do va MO BANG lai chieu ban dau de tiep tuc nhoi trung
//      binh gia. Khac voi CheckTrendReversalClose() o tren: cai do DONG NGAY
//      chuoi dang lo khi dao chieu (cat lo som); Trend Switch GIU NGUYEN chuoi
//      dang lo (khong nhoi them, khong dong), chi "cho" den khi dieu kien huy
//      xay ra moi tiep tuc nhoi lai - phai chon 1 trong 2 co che (xem ValidateInputs).
//----------------------------------------------------------------------

// Doc gia tri ADX hien tai (nen vua dong, shift 1) - dung chung handle h_ADX_Filter
// voi Bo loc ADX cho DCA (Section 2.4c). Fail-open (tra ve 0) neu chua co du lieu.
double GetADXValue()
  {
   if(h_ADX_Filter == INVALID_HANDLE) return(0.0);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_ADX_Filter, 0, 1, 1, buf) < 1) return(0.0);
   return(buf[0]);
  }

// Xu huong moi (doi chieu) co du MANH de kich hoat Trend Switch khong (ADX >=
// InpTrendSwitchADXEnter). Fail-open neu chua co du lieu ADX (an toan, khong chan).
bool TrendSwitchStrengthOk()
  {
   double adx = GetADXValue();
   if(adx <= 0.0) return(true);
   return(adx >= InpTrendSwitchADXEnter);
  }

// Xu huong hien tai co dang YEU DI (ADX < InpTrendSwitchADXExit, coi la "thi truong
// on dinh/di ngang") de tu huy Trend Switch khong - chi co tac dung khi
// InpTrendSwitchUseADXExit = true.
bool TrendSwitchWeakNow()
  {
   if(!InpTrendSwitchUseADXExit) return(false);
   double adx = GetADXValue();
   if(adx <= 0.0) return(false);
   return(adx < InpTrendSwitchADXExit);
  }

// So Pip 1 chuoi dang LO tinh tu Gia trung binh (avgPrice) so voi Gia hien tai theo
// dung huong cua chuoi - tra ve 0 neu dang lai/hoa von (khong tinh la lo).
double SequenceLossPips(const SSequenceState &seq, const int direction, const double currentPrice)
  {
   if(seq.avgPrice <= 0.0) return(0.0);
   double diff = (currentPrice - seq.avgPrice) * direction;
   if(diff >= 0.0) return(0.0);
   return(MathAbs(PriceToPips(diff)));
  }

// Tong Loi nhuan NOI (chua chot) cua CA 2 chuoi + lenh Hedge + Hedging Zone + Mo Nguoc Chieu
// (neu co) - dung lam co so cho 2 kieu nguong "toan Tai khoan" (Kieu 1: %, Kieu 3: Tien) cua
// Trend Switch. UPGRADE (sua loi thieu du lieu): truoc day chi cong GetHedgeProfit(), BO SOT
// GetHedgeZoneProfit() va GetOppositeProfit() - khien "Tong Loi nhuan toan Tai khoan" tinh
// THIEU khi dang co Hedging Zone/Lenh Mo Nguoc Chieu hoat dong song song, co the kich hoat
// (hoac tri hoan kich hoat) Trend Switch SAI thoi diem so voi thuc te tren tai khoan.
double TrendSwitchTotalFloatingProfit()
  {
   return(g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + GetHedgeProfit() + GetHedgeZoneProfit() + GetOppositeProfit());
  }

// Kiem tra dieu kien "dang lo bao nhieu" cua Trend Switch, dua theo Kieu nguong dang
// chon (InpTrendSwitchTriggerMode) - Kieu 1/3 xet TOAN TAI KHOAN (Balance/Tien), Kieu 2
// xet RIENG chuoi dang lo (Pip, tinh tu Gia trung binh, giu dung hanh vi ban dau).
bool TrendSwitchLossThresholdMet(const SSequenceState &seq, const int direction, const double currentPrice)
  {
   switch(InpTrendSwitchTriggerMode)
     {
      case TS_Trigger_PercentAccount:
        {
         double bal = AccountInfoDouble(ACCOUNT_BALANCE);
         if(bal <= 0.0) return(false);
         return(TrendSwitchTotalFloatingProfit() <= -(bal * InpTrendSwitchPercent / 100.0));
        }
      case TS_Trigger_Money:
         return(TrendSwitchTotalFloatingProfit() <= -InpTrendSwitchMoneyLoss);
      case TS_Trigger_Pips:
      default:
         return(SequenceLossPips(seq, direction, currentPrice) >= InpTrendSwitchMinLossPips);
     }
  }

// Chuoi mo ta nguong dang dung, phuc vu Print log cho de doi chieu khi debug.
string TrendSwitchThresholdDesc()
  {
   switch(InpTrendSwitchTriggerMode)
     {
      case TS_Trigger_PercentAccount: return(StringFormat("Tai khoan dang am >= %.1f%% Balance", InpTrendSwitchPercent));
      case TS_Trigger_Money:          return(StringFormat("Tai khoan dang am >= %.2f", InpTrendSwitchMoneyLoss));
      case TS_Trigger_Pips:
      default:                        return(StringFormat("Rieng chuoi dang lo >= %.1f pip", InpTrendSwitchMinLossPips));
     }
  }

// Ty le "lo SAU HON nguong goc bao nhieu LAN" (>= 1.0, cang lon cang nguy hiem) - dung
// lam co so cho Gia han thoi gian THICH UNG (xem TrendSwitchEffectiveGraceMinutes ben
// duoi). Tinh dung theo tung Kieu nguong dang chon, nhat quan voi TrendSwitchLossThresholdMet.
double TrendSwitchSeverityRatio(const SSequenceState &seq, const int direction, const double currentPrice)
  {
   switch(InpTrendSwitchTriggerMode)
     {
      case TS_Trigger_PercentAccount:
        {
         double bal = AccountInfoDouble(ACCOUNT_BALANCE);
         if(bal <= 0.0 || InpTrendSwitchPercent <= 0.0) return(1.0);
         double lossPct = -TrendSwitchTotalFloatingProfit() / bal * 100.0;
         return(MathMax(1.0, lossPct / InpTrendSwitchPercent));
        }
      case TS_Trigger_Money:
         if(InpTrendSwitchMoneyLoss <= 0.0) return(1.0);
         return(MathMax(1.0, (-TrendSwitchTotalFloatingProfit()) / InpTrendSwitchMoneyLoss));
      case TS_Trigger_Pips:
      default:
         if(InpTrendSwitchMinLossPips <= 0.0) return(1.0);
         return(MathMax(1.0, SequenceLossPips(seq, direction, currentPrice) / InpTrendSwitchMinLossPips));
     }
  }

// Gia han thoi gian HIEU LUC (phut) cho Gia han Thich ung (Section 9.2c mo rong): tai
// dung nguong goc (severity=1.0) -> dung InpTrendSwitchGraceMinutes (Gia han co ban); tai
// hoac vuot qua InpTrendSwitchGraceSeverityCap lan nguong -> giam dan toi InpTrendSwitchGraceMinMinutes
// (thap nhat); noi suy TUYEN TINH o giua. Neu tat InpUseTrendSwitchAdaptiveGrace thi luon
// tra ve dung InpTrendSwitchGraceMinutes (hanh vi CU, khong doi).
double TrendSwitchEffectiveGraceMinutes(const double severity)
  {
   if(!InpUseTrendSwitchAdaptiveGrace) return(InpTrendSwitchGraceMinutes);
   if(InpTrendSwitchGraceSeverityCap <= 1.0) return(InpTrendSwitchGraceMinMinutes);
   double t = (severity - 1.0) / (InpTrendSwitchGraceSeverityCap - 1.0);
   t = MathMax(0.0, MathMin(1.0, t));
   return(InpTrendSwitchGraceMinutes - t * (InpTrendSwitchGraceMinutes - InpTrendSwitchGraceMinMinutes));
  }

// Quy tac "nhoi THUAN xu huong" (nhoi duong) danh rieng cho chieu dang "duoi xu huong"
// trong luc Trend Switch dang kich hoat - giong het quy tac Positive_Pyramiding (Section
// 9, dung lai InpPyramidingStepPips/InpPyramidingRequireSignal cho nhat quan, khong them
// Input moi trung lap): chi nhoi khi gia dang co loi (THUAN chieu), du khoang cach
// InpPyramidingStepPips tu lenh gan nhat, va (neu bat) can InpDCASignal xac nhan. Rieng
// so lan nhoi TOI DA (InpTSPyramidMaxLegs) chi ap dung cho chuoi Trend Switch dang duoi
// xu huong nay - KHONG anh huong DCA thuong hay Positive Pyramiding doc lap.
bool ShouldOpenTrendSwitchPyramid(const SSequenceState &seq, const int direction, const double currentPrice)
  {
   if(seq.totalOrders <= 0) return(false);

   // --- Gioi han THEO DOT: moi DOT toi da InpTSPyramidMaxLegs lenh (dem tu SO LENH THAT
   //     trong chuoi - ArraySize(seq.orders) - tru di moc "da co bao nhieu lenh khi DOT nay
   //     bat dau", KHONG tu dem tay, tranh lech neu 1 lenh mo that bai). Day DOT -> TAM DUNG;
   //     neu InpTSPyramidAllowNextBatch bat, sau khi nghi du InpTSPyramidBatchPauseMinutes,
   //     VA chuoi GOC (dang dong bang, phia doi dien) van con am du dung nguong Trend Switch,
   //     VA tin hieu dao chieu (huong dang duoi nay) van con xac nhan lai, thi MO DOT TIEP
   //     THEO (danh dau lai moc bat dau dem). Neu InpTSPyramidAllowNextBatch tat: DOT dau la
   //     TRAN CUNG vinh vien cho lan duoi nay (hanh vi don gian, giu nguyen nhu truoc).
   if(InpTSPyramidMaxLegs > 0)
     {
      int      batchStart = (direction == 1) ? g_buyBatchStartOrders : g_sellBatchStartOrders;
      datetime pauseSince = (direction == 1) ? g_buyBatchPauseSince  : g_sellBatchPauseSince;
      int      legsThisBatch = ArraySize(seq.orders) - batchStart;

      if(legsThisBatch >= InpTSPyramidMaxLegs)
        {
         if(!InpTSPyramidAllowNextBatch) return(false);

         if(pauseSince == 0)
           {
            if(direction == 1) g_buyBatchPauseSince = TimeCurrent(); else g_sellBatchPauseSince = TimeCurrent();
            return(false);
           }

         if((TimeCurrent() - pauseSince) < (long)(InpTSPyramidBatchPauseMinutes * 60.0)) return(false);

         int    frozenDir   = -direction;
         double frozenPrice = (frozenDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         bool   frozenStillBad = (frozenDir == 1) ? TrendSwitchLossThresholdMet(g_buySeq, 1, frozenPrice)
                                                    : TrendSwitchLossThresholdMet(g_sellSeq, -1, frozenPrice);
         bool   signalStillOk  = IsSignalConfirmed(InpEntrySignal, direction);
         if(!frozenStillBad || !signalStillOk) return(false);

         // Du dieu kien -> MO DOT MOI: danh dau lai moc bat dau dem, tat NGHI.
         if(direction == 1) { g_buyBatchStartOrders  = ArraySize(seq.orders); g_buyBatchPauseSince  = 0; }
         else                { g_sellBatchStartOrders = ArraySize(seq.orders); g_sellBatchPauseSince = 0; }
         PrintFormat("[Huuoaifx DCA] Trend Switch: DOT nhoi truoc (%d lenh) da nghi du %.0f phut, chuoi goc van con am du nguong + tin hieu van xac nhan -> MO DOT nhoi TIEP THEO cho chuoi dang duoi xu huong (%s).",
                     InpTSPyramidMaxLegs, InpTSPyramidBatchPauseMinutes, (direction == 1 ? "BUY" : "SELL"));
        }
     }

   if(IsAdverseMove(seq, direction, currentPrice)) return(false);
   double distPips = MathAbs(PriceToPips(currentPrice - seq.lastOpenPrice));
   if(distPips < InpPyramidingStepPips) return(false);
   if(InpPyramidingRequireSignal) return(CheckDCASignal(direction));
   return(true);
  }

// Lot dung cho 1 lan nhoi them cua chuoi Trend Switch dang DUOI XU HUONG: neu bat
// InpTSPyramidFixedLot (mac dinh) thi luon dung LOT CO DINH bang dung Lot cua lenh DAU
// TIEN trong chuoi nay (khong nhan He so tang dan nhu DCA thuong) - tranh tinh trang lenh
// nhoi CUOI CUNG (o diem gia xa nhat, rui ro nhat neu dao chieu dot ngot) lai la lenh Lot
// TO NHAT. Neu tat, quay lai dung ResolveOrderLot() (He so tang dan nhu truoc).
double ResolveTrendSwitchPyramidLot(const int direction, const SSequenceState &seq)
  {
   if(!InpTSPyramidFixedLot) return(ResolveOrderLot(direction, seq));
   if(ArraySize(seq.orders) > 0) return(seq.orders[0].lot);
   return(ResolveOrderLot(direction, seq)); // Fallback an toan (ly thuyet khong xay ra - chuoi duoi luon co it nhat 1 lenh)
  }

// ManageTrendSwitch: dispatcher chinh, goi 1 lan moi tick TRUOC ProcessEntryLogic/
// ProcessDCALogic (xem OnTick, Section 14.4). Tu quyet dinh KICH HOAT (dong bang 1
// chieu dang lo + mo/danh dau chieu con lai la "duoi xu huong") hoac HUY (chot chuoi
// duoi xu huong, mo bang chieu ban dau) dua tren g_trendSwitchState hien tai.
void ManageTrendSwitch(const bool canOpenNewSequence)
  {
   if(!InpUseTrendSwitch) { g_trendSwitchState = 0; return; }

   // --- DANG KICH HOAT: chi xet dieu kien HUY (khong xet kich hoat moi trong luc nay)
   if(g_trendSwitchState != 0)
     {
      int chaseDir  = g_trendSwitchState;      // Huong dang "duoi" xu huong (dang nhoi thuan)
      int frozenDir = -g_trendSwitchState;     // Huong dang bi dong bang (giu nguyen, cho)

      bool chaseActive = (chaseDir == 1) ? g_buySeq.active : g_sellSeq.active;
      if(!chaseActive)
        {
         PrintFormat("[Huuoaifx DCA] Trend Switch: chuoi dang duoi xu huong (%s) da tu dong (TP/SL/Trailing...) -> huy trang thai, cho phep %s nhoi tro lai binh thuong.",
                     (chaseDir == 1 ? "BUY" : "SELL"), (frozenDir == 1 ? "BUY" : "SELL"));
         g_trendSwitchState = 0;
         if(chaseDir == 1) { g_buyBatchStartOrders  = 0; g_buyBatchPauseSince  = 0; }
         else                { g_sellBatchStartOrders = 0; g_sellBatchPauseSince = 0; }
         return;
        }

      bool reverseSignal = IsSignalConfirmed(InpEntrySignal, frozenDir);
      bool marketCalm    = TrendSwitchWeakNow();

      // Thoat khi HET DA (Section 9.2c mo rong): chuoi dang duoi xu huong TUNG co lai
      // (peakProfit > 0) nhung da LAU khong lap dinh loi nhuan MOI (peakProfitTime dung
      // yen qua InpTrendSwitchStallMinutes) -> coi la thi truong da on dinh/di ngang, cho
      // THOAT du tin hieu chua dao lai va ADX chua tut duoi InpTrendSwitchADXExit. Day la
      // dieu kien DOC LAP voi ADX/tin hieu, chuyen bat dung kieu dao chieu CHAM ma ca 2 cai
      // kia deu co the phan ung tre.
      double   chasePeak     = (chaseDir == 1) ? g_buySeq.peakProfit     : g_sellSeq.peakProfit;
      datetime chasePeakTime = (chaseDir == 1) ? g_buySeq.peakProfitTime : g_sellSeq.peakProfitTime;
      bool stalled = (InpUseTrendSwitchStallExit && chasePeak > 0.0 && chasePeakTime != 0 &&
                     (TimeCurrent() - chasePeakTime) >= (long)(InpTrendSwitchStallMinutes * 60.0));

      if(reverseSignal || marketCalm || stalled)
        {
         string reason = reverseSignal ? "Tin hieu dao chieu tro lai xac nhan" :
                         (marketCalm   ? "ADX yeu di (thi truong on dinh/di ngang)" :
                                         StringFormat("HET DA (khong lap dinh loi nhuan moi >= %.0f phut, thi truong dang di ngang)", InpTrendSwitchStallMinutes));
         PrintFormat("[Huuoaifx DCA] Trend Switch: %s -> CHOT toan bo chuoi duoi xu huong (%s), MO BANG cho phep %s nhoi tro lai de trung binh gia ve bo.",
                     reason, (chaseDir == 1 ? "BUY" : "SELL"), (frozenDir == 1 ? "BUY" : "SELL"));
         if(chaseDir == 1) { CloseAllOrdersInSequence(g_buySeq);  g_buySeq.recoveryCycle  = 0; }
         else              { CloseAllOrdersInSequence(g_sellSeq); g_sellSeq.recoveryCycle = 0; }
         SyncSequenceFromPositions();
         g_trendSwitchState = 0;
         if(chaseDir == 1) { g_buyBatchStartOrders  = 0; g_buyBatchPauseSince  = 0; }
         else                { g_sellBatchStartOrders = 0; g_sellBatchPauseSince = 0; }
        }
      return;
     }

   // --- BINH THUONG: xet kich hoat moi - chi 1 chieu duoc kich hoat tai 1 thoi diem,
   //     va chi khi chieu con lai CHUA active (tranh chong cheo voi truong hop ca 2
   //     chuoi da cung dang chay doc lap tu truoc do).
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Chuoi nao KHONG con active thi ve 0 moc thoi gian "dang lo lien tuc" tuong ung (Gia han
   // thoi gian - xem khai bao g_buyLossSince/g_sellLossSince): chuoi da chot thi coi nhu
   // chuoi kiem "lo lien tuc" da ket thuc, lan sau mo chuoi moi se tinh lai tu dau.
   if(!g_buySeq.active)  g_buyLossSince  = 0;
   if(!g_sellSeq.active) g_sellLossSince = 0;

   if(g_buySeq.active && !g_sellSeq.active)
     {
      bool lossMet = TrendSwitchLossThresholdMet(g_buySeq, 1, bid);
      if(lossMet) { if(g_buyLossSince == 0) g_buyLossSince = TimeCurrent(); }
      else          g_buyLossSince = 0;

      bool strengthOk    = TrendSwitchStrengthOk();
      double severity    = TrendSwitchSeverityRatio(g_buySeq, 1, bid);
      double graceMin    = TrendSwitchEffectiveGraceMinutes(severity);
      bool graceElapsed  = (InpTrendSwitchUseTimeFallback && g_buyLossSince != 0 &&
                            (TimeCurrent() - g_buyLossSince) >= (long)(graceMin * 60.0));
      bool timeFallback  = (!strengthOk && graceElapsed); // Chi dung khi ADX CHUA du manh

      if(lossMet && IsSignalConfirmed(InpEntrySignal, -1) && (strengthOk || timeFallback))
        {
         if(timeFallback)
            PrintFormat("[Huuoaifx DCA] Trend Switch KICH HOAT (Gia han thoi gian, lo x%.2f nguong -> Gia han hieu luc %.0f phut): %s + tin hieu dao chieu GIAM xac nhan, nhung ADX chua toi %.1f - da LO LIEN TUC du Gia han (thi truong 'lu lu' di, khong bien dong manh) -> van DONG BANG nhoi BUY, MO chuoi SELL duoi xu huong de bao ve tai khoan.",
                        severity, graceMin, TrendSwitchThresholdDesc(), InpTrendSwitchADXEnter);
         else
            PrintFormat("[Huuoaifx DCA] Trend Switch KICH HOAT: %s + tin hieu dao chieu GIAM xac nhan manh (ADX>=%.1f) -> DONG BANG nhoi BUY, MO chuoi SELL duoi xu huong.",
                        TrendSwitchThresholdDesc(), InpTrendSwitchADXEnter);
         g_trendSwitchState = -1; // SELL dang duoi, BUY bi dong bang
         g_buyLossSince = 0; // Da kich hoat xong - ve 0, lan sau (neu tai kich hoat lai) tinh lai tu dau
         g_sellBatchStartOrders = 0; g_sellBatchPauseSince = 0; // Chuoi SELL vua mo, DOT nhoi dau tien bat dau tu 0 lenh
         if(canOpenNewSequence && CanStartNewSequenceNow(-1))
            OpenNewOrder(-1, ResolveOrderLot(-1, g_sellSeq));
         return;
        }
     }

   if(g_sellSeq.active && !g_buySeq.active)
     {
      bool lossMet = TrendSwitchLossThresholdMet(g_sellSeq, -1, ask);
      if(lossMet) { if(g_sellLossSince == 0) g_sellLossSince = TimeCurrent(); }
      else          g_sellLossSince = 0;

      bool strengthOk    = TrendSwitchStrengthOk();
      double severity    = TrendSwitchSeverityRatio(g_sellSeq, -1, ask);
      double graceMin    = TrendSwitchEffectiveGraceMinutes(severity);
      bool graceElapsed  = (InpTrendSwitchUseTimeFallback && g_sellLossSince != 0 &&
                            (TimeCurrent() - g_sellLossSince) >= (long)(graceMin * 60.0));
      bool timeFallback  = (!strengthOk && graceElapsed); // Chi dung khi ADX CHUA du manh

      if(lossMet && IsSignalConfirmed(InpEntrySignal, 1) && (strengthOk || timeFallback))
        {
         if(timeFallback)
            PrintFormat("[Huuoaifx DCA] Trend Switch KICH HOAT (Gia han thoi gian, lo x%.2f nguong -> Gia han hieu luc %.0f phut): %s + tin hieu dao chieu TANG xac nhan, nhung ADX chua toi %.1f - da LO LIEN TUC du Gia han (thi truong 'lu lu' di, khong bien dong manh) -> van DONG BANG nhoi SELL, MO chuoi BUY duoi xu huong de bao ve tai khoan.",
                        severity, graceMin, TrendSwitchThresholdDesc(), InpTrendSwitchADXEnter);
         else
            PrintFormat("[Huuoaifx DCA] Trend Switch KICH HOAT: %s + tin hieu dao chieu TANG xac nhan manh (ADX>=%.1f) -> DONG BANG nhoi SELL, MO chuoi BUY duoi xu huong.",
                        TrendSwitchThresholdDesc(), InpTrendSwitchADXEnter);
         g_trendSwitchState = 1; // BUY dang duoi, SELL bi dong bang
         g_sellLossSince = 0; // Da kich hoat xong - ve 0, lan sau (neu tai kich hoat lai) tinh lai tu dau
         g_buyBatchStartOrders = 0; g_buyBatchPauseSince = 0; // Chuoi BUY vua mo, DOT nhoi dau tien bat dau tu 0 lenh
         if(canOpenNewSequence && CanStartNewSequenceNow(1))
            OpenNewOrder(1, ResolveOrderLot(1, g_buySeq));
         return;
        }
     }
  }

//----------------------------------------------------------------------
// 11.3 HEDGING (Section 2.11) - Mo 1 lenh Hedge nguoc chieu khi 1 trong cac
//      dieu kien kich hoat duoc bat (So lenh cua chuoi dang am nhat, HOAC %
//      Drawdown toan tai khoan) xay ra; TP tinh theo Pips tren chinh lenh Hedge
//      (InpHedgeTP_Money - ten bien giu nguyen nhung nay mang y nghia "pips" theo
//      dung nhu cau), SL van tinh theo Tien (InpHedgeSL_Money), VA them TP TONG
//      theo Tien rieng cho ca cap Hedge (InpHedgeTotalTPMoney).
//----------------------------------------------------------------------
bool OpenHedgeOrder(const int direction, double lot)
  {
   lot = NormalizeLotValue(lot);
   if(lot < g_sym.volumeMin) return(false);

   string hedgeComment = InpOrderComment + HEDGE_TAG;
   bool ok = (direction == 1) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, hedgeComment)
                               : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, hedgeComment);
   if(!ok)
     {
      PrintFormat("[Huuoaifx DCA] Loi mo lenh Hedge %s Lot=%.2f: %d - %s",
                  (direction == 1 ? "BUY" : "SELL"), lot, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return(false);
     }

   PrintFormat("[Huuoaifx DCA] Hedging: da mo lenh Hedge %s Lot=%.2f.", (direction == 1 ? "BUY" : "SELL"), lot);
   SyncSequenceFromPositions();
   return(true);
  }

void CheckHedgeZoneTrigger()
  {
   if(!InpUseHedging) return;
   if(g_hedge.active) return; // Chi cho phep toi da 1 lenh Hedge tai 1 thoi diem
   if(g_buySeq.totalOrders == 0 && g_sellSeq.totalOrders == 0) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return;

   double combinedFloating = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit;
   double ddPercent = (-combinedFloating / bal) * 100.0;

   // 3 dieu kien kich hoat DOC LAP (OR voi nhau), moi dieu kien co the tu tat rieng:
   int    neediestOrders = (int)MathMax(g_buySeq.totalOrders, g_sellSeq.totalOrders);
   bool   hitCount   = (InpHedgeActivateCount > 0) && (neediestOrders >= InpHedgeActivateCount);
   bool   hitPercent = (InpHedgePercent != 0.0) && (ddPercent >= MathAbs(InpHedgePercent));
   bool   hitAdvPct  = (InpHedgeZoneTriggerPercent > 0.0) && (ddPercent >= InpHedgeZoneTriggerPercent);
   if(!hitCount && !hitPercent && !hitAdvPct) return;

   int    hedgeDir;
   double baseLot;
   if(g_buySeq.sequenceProfit <= g_sellSeq.sequenceProfit) { hedgeDir = -1; baseLot = g_buySeq.totalLot; }
   else                                                     { hedgeDir = 1;  baseLot = g_sellSeq.totalLot; }

   if(baseLot <= 0.0) return;

   // InpHedgeUseDCALotForHedge=true -> dung dung Lot DCA tiep theo (khoi luong lenh
   // tiep theo trong chuoi neu ban vao them) lam khoi luong Hedge; false (mac dinh)
   // -> InpHedgeLotMultiplier duoc hieu la PHAN TRAM (%) so voi Tong Lot dang ho tro.
   double hedgeLot;
   if(InpHedgeUseDCALotForHedge)
     {
      // Luu y: MQL5 khong cho phep toan tu ?: tren kieu struct -> dung if/else tuong minh
      SSequenceState needySeq;
      if(hedgeDir == -1) needySeq = g_buySeq; else needySeq = g_sellSeq;
      hedgeLot = ResolveOrderLot(-hedgeDir, needySeq); // Lot ma phia dang am se dung cho DCA tiep theo
     }
   else
      hedgeLot = baseLot * (InpHedgeLotMultiplier / 100.0);

   OpenHedgeOrder(hedgeDir, hedgeLot);
  }

double GetHedgeProfit()
  {
   if(!g_hedge.active) return(0.0);
   if(!PositionSelectByTicket(g_hedge.ticket)) return(0.0);
   // UPGRADE (sua loi mat tien Hoa hong): cong them POSITION_COMMISSION.
   return(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION));
  }

// --- BAO VE KHI CHOT CHUNG VOI HEDGE NGUOC CHIEU (Section 2.11, InpHedgeCloseMinProfit) -
//     dung CHUNG cho ca 5 ham chot/dong chuoi co the vo tinh keo dong theo Hedge nguoc
//     chieu dang am nang: EvaluateChainTP / EvaluateEmergencyTP / EvaluatePostTrimTP (chot
//     theo Pips) VA EvaluateStepProfitLock / ManageTrailingStop (chot theo Loi nhuan Bac
//     thang / Trailing Stop) - xem loi goi trong tung ham. Neu lenh Hedge dang mo NGUOC
//     CHIEU voi chuoi nay (g_hedge.direction == -direction - dung quy uoc da xac nhan:
//     Hedge luon mo CUNG chieu voi ben THANG THE tai thoi diem kich hoat, tuc la NGUOC
//     chieu voi chinh ben YEU HON dang duoc no ho tro), thi du Gia da cham muc tieu Pips
//     (hit=true) VAN CHUA DUOC DONG neu Tong loi nhuan thuc te (seq.sequenceProfit + Loi/Lo
//     hien tai cua Hedge) CHUA vuot InpHedgeCloseMinProfit - tranh tinh trang chuoi vua chom
//     lai chut it da bi Hedge (thuong Lot lon, dang am nang o vung gia bat loi) keo tut am
//     rong ca cap khi dong chung (CloseAllOrdersInSequence tu dong dong LUON Hedge nguoc
//     chieu - xem Section 9.1c).
//
//     SUA LO HONG (Fatal Bug #4): TRUOC DAY co dong "if(InpHedgeCloseMinProfit == 0.0)
//     return(false);" o dau ham - dieu nay VO TINH TAT HAN bo loc nay bat cu khi nao Nguoi
//     dung dat InpHedgeCloseMinProfit = 0.0 (y dinh THUC SU cua Nguoi dung khi dat 0.0 la
//     "chi can Hoa von tro len la duoc chot, KHONG duoc am"), thay vi chay xuong dieu kien
//     totalCombinedProfit < InpHedgeCloseMinProfit (tuc la < 0.0) de dung bat buoc khong
//     duoc am tien. Nay: XOA dong kiem tra do - de InpHedgeCloseMinProfit=0.0 van chay
//     binh thuong xuong dieu kien ben duoi (chi chan khi Tong loi nhuan < 0.0, tuc dang AM).
//     Muon VO HIEU HOA HAN bo loc nay, Nguoi dung phai chu dong dat 1 gia tri SIEU AM (VD
//     -99999.0) - khi do dieu kien "totalCombinedProfit < -99999.0" gan nhu khong bao gio
//     dung (tru khi tai khoan thuc su am toi muc do dot bien), tuong duong TAT bo loc.
bool HedgeCloseGuardBlocks(const SSequenceState &seq, const int direction)
  {
   if(!g_hedge.active || g_hedge.direction != -direction) return(false);

   double hedgeProfit         = GetHedgeProfit();
   double totalCombinedProfit = seq.sequenceProfit + hedgeProfit;
   if(totalCombinedProfit < InpHedgeCloseMinProfit)
     {
      PrintFormat("[Huuoaifx DCA] Bao ve Hedge (%s): Da cham muc tieu Pips nhung Tong loi nhuan Chuoi+Hedge = %.2f (Chuoi %.2f + Hedge %.2f) chua dat toi thieu %.2f -> CHUA dong, tiep tuc gong cho du tien bu Hedge.",
                  (direction == 1 ? "BUY" : "SELL"), totalCombinedProfit, seq.sequenceProfit, hedgeProfit, InpHedgeCloseMinProfit);
      return(true);
     }
   return(false);
  }

void ManageHedgePosition()
  {
   if(!g_hedge.active) return;

   double profit = GetHedgeProfit();

   // TP hedging tinh theo PIPS (tu Gia mo lenh Hedge), SL van tinh theo Tien.
   double curPrice = (g_hedge.direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitPips = PriceToPips((curPrice - g_hedge.openPrice) * g_hedge.direction);
   bool hitTP = (InpHedgeTP_Money > 0.0) && (profitPips >= InpHedgeTP_Money);
   bool hitSL = (InpHedgeSL_Money > 0.0) && (profit <= -InpHedgeSL_Money);
   // TP TONG theo Tien cho ca cap Hedge (Lenh goc dang ho tro + Lenh Hedge cong lai)
   bool hitTotalTP = (InpHedgeTotalTPMoney > 0.0) &&
                      ((g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + profit) >= InpHedgeTotalTPMoney);

   if(!hitTP && !hitSL && !hitTotalTP) return;

   // --- SUA LOI "BO ROI CHUOI" CUA HEDGE THUONG (Fatal Bug #2): TRUOC DAY khi hitTotalTP
   //     dung (dat TP TONG bang Tien cho ca cap Hedge - tinh tren CA hai chuoi goc CONG lenh
   //     Hedge), code CHI dong mỗi lenh Hedge (trade.PositionClose(g_hedge.ticket)), BO LAI
   //     nguyen 2 chuoi Buy/Sell goc (chinh 2 chuoi nay moi la nguon tao ra phan Loi nhuan
   //     duoc cong vao Total TP) - mac ket ngoai thi truong, khong duoc chot loi cung luc.
   //     Nay: dat Total TP phai dong TOAN BO EA (ca 2 chuoi goc + Hedge, dung CloseAllEAOrders),
   //     giong het co che "giai cuu ca cap" da ap dung cho Hedging Zone (ManageHedgingZone).
   if(hitTotalTP)
     {
      PrintFormat("[Huuoaifx DCA] Total TP Hedge dat %.2f -> Dong toan bo EA.",
                  (g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + profit));
      CloseAllEAOrders();
      g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
      SyncSequenceFromPositions();
      return;
     }

   // Neu chi hitTP hoac hitSL (cua rieng lenh Hedge) - giu nguyen logic dong lenh Hedge hien tai
   string reason = hitTP ? "TP" : "SL";
   if(trade.PositionClose(g_hedge.ticket))
      PrintFormat("[Huuoaifx DCA] Hedge %s: da dong lenh Hedge #%I64u, Profit=%.2f.", reason, g_hedge.ticket, profit);
   else
      PrintFormat("[Huuoaifx DCA] Loi dong lenh Hedge #%I64u: %d - %s",
                  g_hedge.ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());

   SyncSequenceFromPositions();
  }

//----------------------------------------------------------------------
// 11.3z HEDGING ZONE (Section 2.10) - KHAC voi Hedging o tren: kich hoat theo
//       So lenh cua chuoi (khong phai %DD), mo lenh bang TONG LOT nhan He so
//       (khong phai theo % ho tro), gioi han trong 1 Vung gia (Band Pips) tu
//       gia mo lenh, va co TP TONG rieng theo Tien hoac Pips.
//----------------------------------------------------------------------
bool OpenHedgeZoneOrder(const int direction, double lot)
  {
   lot = NormalizeLotValue(lot);
   if(InpHedgeZoneMaxLot > 0.0 && lot > InpHedgeZoneMaxLot) lot = InpHedgeZoneMaxLot;
   lot = NormalizeLotValue(lot);
   if(lot < g_sym.volumeMin) return(false);

   string cmt = InpOrderComment + HEDGEZONE_TAG;
   bool ok = (direction == 1) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, cmt)
                               : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, cmt);
   if(!ok)
     {
      PrintFormat("[Huuoaifx DCA] Loi mo lenh Hedging Zone %s Lot=%.2f: %d - %s",
                  (direction == 1 ? "BUY" : "SELL"), lot, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return(false);
     }

   PrintFormat("[Huuoaifx DCA] Hedging Zone: da mo lenh %s Lot=%.2f.", (direction == 1 ? "BUY" : "SELL"), lot);
   SyncSequenceFromPositions();
   return(true);
  }

void CheckHedgingZoneTrigger()
  {
   if(!InpUseHedgingZone) return;
   if(g_hedgeZone.active) return;

   SSequenceState needySeq; int needyDir;
   if(g_buySeq.totalOrders >= InpHedgeZoneActivateCount && g_buySeq.sequenceProfit <= g_sellSeq.sequenceProfit)
     { needySeq = g_buySeq; needyDir = 1; }
   else if(g_sellSeq.totalOrders >= InpHedgeZoneActivateCount)
     { needySeq = g_sellSeq; needyDir = -1; }
   else
      return;

   if(!needySeq.active || needySeq.totalLot <= 0.0) return;

   double curPrice = (needyDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double distPips = MathAbs(PriceToPips(curPrice - needySeq.avgPrice));
   if(InpHedgeZoneBandPips > 0.0 && distPips < InpHedgeZoneBandPips) return; // Chua vao du Vung gia quy dinh

   OpenHedgeZoneOrder(-needyDir, needySeq.totalLot * InpHedgeZoneLotMultiplier);
  }

double GetHedgeZoneProfit()
  {
   if(!g_hedgeZone.active) return(0.0);
   if(!PositionSelectByTicket(g_hedgeZone.ticket)) return(0.0);
   // UPGRADE (sua loi mat tien Hoa hong): cong them POSITION_COMMISSION.
   return(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION));
  }

void ManageHedgingZone()
  {
   if(!g_hedgeZone.active) return;

   double hzProfit = GetHedgeZoneProfit();
   double totalCombined = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + hzProfit;

   double closeMoney = InpHedgeZoneNewMoneyActivateCount > 0 &&
                        (g_buySeq.totalOrders + g_sellSeq.totalOrders) >= InpHedgeZoneNewMoneyActivateCount
                        ? InpHedgeZoneNewMoney : InpHedgeZoneCloseMoney;

   double hzCurPrice = (g_hedgeZone.direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double hzDistPips = PriceToPips(MathAbs(hzCurPrice - g_hedgeZone.openPrice));

   bool hitMoney = (closeMoney > 0.0) && (totalCombined >= closeMoney);
   // Chi dung Pips TP khi Money TP dang OFF (closeMoney<=0) - dong khi lenh Hedging Zone
   // dang co Lai VA da di du xa (InpHedgeZoneClosePips) tinh tu Gia mo lenh.
   bool hitPips  = (closeMoney <= 0.0) && (InpHedgeZoneClosePips > 0.0) && (hzProfit >= 0.0) && (hzDistPips >= InpHedgeZoneClosePips);

   if(!hitMoney && !hitPips) return;

   // SUA LOI BO ROI CHUOI DANG AM (yeu cau nguoi dung): truoc day khi Hedging Zone chot
   // loi, EA CHI dong mỗi lenh g_hedgeZone.ticket, BO LAI nguyen chuoi dang duoc no bao ve
   // (chuoi nguoc chieu voi Hedging Zone, thuong dang am rat nang - chinh ly do Hedging Zone
   // duoc mo ra tu dau) van tiep tuc mac ket ngoai thi truong. Nay: sau khi dong THANH CONG
   // lenh Hedging Zone, dong LUON ca chuoi dang duoc bao ve (nguoc chieu voi g_hedgeZone.direction)
   // de "tat toan" ca cap cung 1 luc, dung tinh than "Hedging Zone = giai cuu ca cap".
   int hzDir = g_hedgeZone.direction;
   if(trade.PositionClose(g_hedgeZone.ticket))
     {
      PrintFormat("[Huuoaifx DCA] Hedging Zone: da dong lenh #%I64u (Tong P/L=%.2f).", g_hedgeZone.ticket, totalCombined);
      if(hzDir == -1 && g_buySeq.active)
        {
         PrintFormat("[Huuoaifx DCA] Hedging Zone: dong LUON chuoi BUY dang duoc bao ve (nguoc chieu voi Hedging Zone).");
         CloseAllOrdersInSequence(g_buySeq);
         g_buySeq.recoveryCycle = 0;
        }
      else if(hzDir == 1 && g_sellSeq.active)
        {
         PrintFormat("[Huuoaifx DCA] Hedging Zone: dong LUON chuoi SELL dang duoc bao ve (nguoc chieu voi Hedging Zone).");
         CloseAllOrdersInSequence(g_sellSeq);
         g_sellSeq.recoveryCycle = 0;
        }
     }
   else
      PrintFormat("[Huuoaifx DCA] Loi dong lenh Hedging Zone #%I64u: %d - %s",
                  g_hedgeZone.ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());

   SyncSequenceFromPositions();
  }

//----------------------------------------------------------------------
// 11.3y MO LENH NGUOC CHIEU (Section 2.6) - Sau khi 1 chuoi dat du So lenh
//       kich hoat (InpOppositeActivateCount), mo 1 lenh DUY NHAT o huong
//       NGUOC LAI (khong nhoi them) de giam rui ro mot chieu. Tu dong dong
//       theo khi chuoi goc dong het (xem OnTick 14.2/ManageOppositeOrder).
//----------------------------------------------------------------------
bool OpenOppositeOrder(const int direction, double lot)
  {
   lot = NormalizeLotValue(lot);
   if(lot < g_sym.volumeMin) return(false);

   string cmt = InpOrderComment + OPPOSITE_TAG;
   bool ok = (direction == 1) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, cmt)
                               : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, cmt);
   if(!ok)
     {
      PrintFormat("[Huuoaifx DCA] Loi mo lenh Nguoc Chieu %s Lot=%.2f: %d - %s",
                  (direction == 1 ? "BUY" : "SELL"), lot, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return(false);
     }

   PrintFormat("[Huuoaifx DCA] Mo Lenh Nguoc Chieu: da mo lenh %s Lot=%.2f.", (direction == 1 ? "BUY" : "SELL"), lot);
   SyncSequenceFromPositions();
   return(true);
  }

void ManageOppositeOrder(const int direction)
  {
   // MQL5 khong ho tro toan tu ?: tren kieu struct -> dung if/else tuong minh
   SSequenceState parentSeq; SOppositeState oppState;
   if(direction == 1) { parentSeq = g_buySeq; oppState = g_oppBuy; }
   else                { parentSeq = g_sellSeq; oppState = g_oppSell; }

   if(!parentSeq.active)
     {
      if(oppState.active)
        {
         if(trade.PositionClose(oppState.ticket))
            PrintFormat("[Huuoaifx DCA] Mo Lenh Nguoc Chieu: da dong lenh #%I64u (chuoi goc %s da dong het).",
                        oppState.ticket, (direction == 1 ? "BUY" : "SELL"));
         SyncSequenceFromPositions();
        }
      return;
     }

   if(!InpUseOppositeOrder) return;
   if(oppState.active) return;
   if(parentSeq.totalOrders < InpOppositeActivateCount) return;

   double lot = (InpOppositeLotPercent > 0.0) ? (parentSeq.totalLot * InpOppositeLotPercent / 100.0) : InpOppositeFixLot;
   OpenOppositeOrder(-direction, lot);
  }

// GetOppositeProfit (UPGRADE moi): Tong Loi nhuan hien tai (Profit+Swap+Commission) cua CA 2
// Lenh Mo Nguoc Chieu (g_oppBuy/g_oppSell, Section 2.6) neu dang active - truoc day cac ham
// tinh Tong Loi nhuan toan Tai khoan (TrendSwitchTotalFloatingProfit/EvaluateAccountTargets)
// hoan toan BO SOT phan Loi/Lo cua 2 lenh nay, gay sai lech so voi thuc te tren tai khoan.
double GetOppositeProfit()
  {
   double total = 0.0;
   if(g_oppBuy.active && PositionSelectByTicket(g_oppBuy.ticket))
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
   if(g_oppSell.active && PositionSelectByTicket(g_oppSell.ticket))
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
   return(total);
  }

//----------------------------------------------------------------------
// 11.3b CAN LOTS / LOT EQUALIZER (Section 2.9) - Khi chenh lech |Tong Lot
//      Buy - Tong Lot Sell| vuot InpLotDiffTrigger, tu dong them Lot o phia
//      dang IT Lot hon; tu dong dong/dung lai khi chenh lech da giam ve duoi
//      InpLotDiffStop. InpEqualizerMode quyet dinh mo lenh DOC LAP (tag rieng,
//      #EQLZ) hay NHAP THANG vao chuoi dang it Lot hon (khong tag, tinh luon
//      vao totalOrders/totalLot cua chuoi do). InpEqualizerDelaySec: do tre
//      toi thieu giua 2 lan them Lot lien tiep.
//----------------------------------------------------------------------
bool OpenEqualizerOrder(const int direction, double lot)
  {
   lot = NormalizeLotValue(lot);
   if(lot < g_sym.volumeMin) return(false);

   string eqComment = (InpEqualizerMode == Equalizer_Independent) ? (InpOrderComment + EQUALIZER_TAG) : InpOrderComment;
   bool ok = (direction == 1) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, eqComment)
                               : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, eqComment);
   if(!ok)
     {
      PrintFormat("[Huuoaifx DCA] Loi mo lenh Can bang Lot %s Lot=%.2f: %d - %s",
                  (direction == 1 ? "BUY" : "SELL"), lot, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return(false);
     }

   PrintFormat("[Huuoaifx DCA] Can Lots: da mo lenh %s Lot=%.2f (Che do: %s).",
               (direction == 1 ? "BUY" : "SELL"), lot, EnumToString(InpEqualizerMode));
   g_lastEqualizerOpenTime = (double)TimeCurrent();
   SyncSequenceFromPositions();
   return(true);
  }

void CheckLotEqualizer()
  {
   if(!InpUseLotEqualizer) return;

   double lotDiff = g_buySeq.totalLot - g_sellSeq.totalLot; // > 0: Buy nhieu Lot hon Sell

   if(InpEqualizerMode == Equalizer_Independent && g_equalizer.active)
     {
      if(MathAbs(lotDiff) <= InpLotDiffStop)
        {
         if(trade.PositionClose(g_equalizer.ticket))
            PrintFormat("[Huuoaifx DCA] Can Lots: da dong lenh Can bang #%I64u (chenh lech da giam con %.2f).",
                        g_equalizer.ticket, MathAbs(lotDiff));
         else
            PrintFormat("[Huuoaifx DCA] Loi dong lenh Can bang #%I64u: %d - %s",
                        g_equalizer.ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
         SyncSequenceFromPositions();
        }
      return;
     }

   if(MathAbs(lotDiff) <= InpLotDiffTrigger) return;

   if(InpEqualizerDelaySec > 0 && g_lastEqualizerOpenTime > 0 &&
      (TimeCurrent() - (datetime)g_lastEqualizerOpenTime) < InpEqualizerDelaySec) return;

   int dir = (lotDiff > 0) ? -1 : 1; // Phia nao dang IT Lot hon -> mo them phia do de can bang
   OpenEqualizerOrder(dir, InpBalancingLot);
  }

//----------------------------------------------------------------------
// 11.4 TARGET PROFIT & RISK - TP/SL rieng cho Toan tai khoan / Buy / Sell
//      (Money hoac % Balance), va Loi nhuan bac thang (Step/Ladder Lock).
//----------------------------------------------------------------------
void EvaluateAccountTargets()
  {
   if(!InpUseAccountTP && !InpUseAccountSL && !InpUseAccountSL_Money && InpCloseAllPercentDiff <= 0.0) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   // UPGRADE (sua loi thieu du lieu): truoc day CHI cong GetHedgeProfit(), BO SOT Loi/Lo cua
   // Hedging Zone (GetHedgeZoneProfit) va Lenh Mo Nguoc Chieu (GetOppositeProfit) - khien Money
   // TP/SL Toan tai khoan (InpUseAccountTP/InpUseAccountSL/InpUseAccountSL_Money) tinh THIEU so
   // voi Tong Loi nhuan THUC TE tren tai khoan khi cac tinh nang nay dang hoat dong song song.
   double totalProfit = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + GetHedgeProfit() + GetHedgeZoneProfit() + GetOppositeProfit();

   // Close All khi % chenh lech Lai/Lo giua chuoi Buy va Sell (so voi Balance)
   // vuot InpCloseAllPercentDiff - phat hien tinh huong 1 ben da "chay xa" con
   // ben kia van dam DCA, du Tong P/L toan tai khoan co the chua dat Target/Risk.
   // MIEN TRU khi Trend Switch (Section 9.2c) dang kich hoat (g_trendSwitchState != 0):
   // 1 ben "chay xa" con ben kia dang bi dong bang la CHINH XAC trang thai mong muon cua
   // Trend Switch, khong phai loi - khong duoc Dong toan bo som o day.
   if(InpCloseAllPercentDiff > 0.0 && bal > 0.0 && g_buySeq.active && g_sellSeq.active && g_trendSwitchState == 0)
     {
      double diffPercent = MathAbs(g_buySeq.sequenceProfit - g_sellSeq.sequenceProfit) / bal * 100.0;
      if(diffPercent >= InpCloseAllPercentDiff)
        {
         PrintFormat("[Huuoaifx DCA] Chenh lech Lai/Lo Buy-Sell dat %.1f%% >= %.1f%% -> Dong toan bo.", diffPercent, InpCloseAllPercentDiff);
         CloseAllEAOrders();
         g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
         return;
        }
     }

   // MIEN TRU Money TP Toan tai khoan khi Trend Switch dang kich hoat (g_trendSwitchState != 0):
   // luc nay 1 chuoi dang bi dong bang (thuong dang lo) va 1 chuoi dang "duoi xu huong" (dang
   // xay lai) - neu khong mien tru, Tong P/L 2 chuoi cong lai co the vo tinh cham InpAccountTP_Value
   // va Dong toan bo CA chuoi dang duoi xu huong lan chuoi dang bi dong bang, cat ngang dung y
   // "giu nguyen lai cho den khi Trend Switch tu quyet dinh" cua tinh nang.
   if(InpUseAccountTP && g_trendSwitchState == 0)
     {
      double target = InpAccountTP_IsPercent ? (bal * InpAccountTP_Value / 100.0) : InpAccountTP_Value;
      if(totalProfit >= target)
        {
         PrintFormat("[Huuoaifx DCA] Target Profit (Toan tai khoan) dat %.2f >= %.2f -> Dong toan bo.", totalProfit, target);
         CloseAllEAOrders();
         g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
         return;
        }
     }
   // SL Lop 1 (theo % hoac Tien, tuy InpAccountSL_IsPercent) - KHONG bao gio mien tru Trend
   // Switch/dieu kien nao khac, day la Loi bao ve cuoi cung.
   if(InpUseAccountSL)
     {
      double target = InpAccountSL_IsPercent ? (bal * InpAccountSL_Value / 100.0) : InpAccountSL_Value;
      if(totalProfit <= -target)
        {
         PrintFormat("[Huuoaifx DCA] Target Risk Lop 1 (Toan tai khoan, %s) cham %.2f <= -%.2f -> Dong toan bo.",
                     (InpAccountSL_IsPercent ? "%Balance" : "So tien"), totalProfit, target);
         CloseAllEAOrders();
         g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
         return;
        }
     }
   // SL Lop 2 (LUON theo SO TIEN CU THE, doc lap hoan toan voi Lop 1 o tren) - cho phep bat
   // CA 2 lop cung luc lam 2 nguong bao ve song song (VD Lop 1 = -30% Balance, Lop 2 = -30.000
   // tien te tai khoan co dinh) - cham nguong nao truoc thi Dong toan bo truoc. Cung KHONG bao
   // gio mien tru Trend Switch/dieu kien nao khac.
   if(InpUseAccountSL_Money && InpAccountSL_MoneyValue > 0.0)
     {
      if(totalProfit <= -InpAccountSL_MoneyValue)
        {
         PrintFormat("[Huuoaifx DCA] Target Risk Lop 2 (Toan tai khoan, So tien cu the) cham %.2f <= -%.2f -> Dong toan bo.",
                     totalProfit, InpAccountSL_MoneyValue);
         CloseAllEAOrders();
         g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
        }
     }
  }

void EvaluateSideTargets(SSequenceState &seq, const int direction, const bool useTP, const bool tpPct, const double tpVal,
                          const bool useSL, const bool slPct, const double slVal)
  {
   if(!seq.active) return;
   if(!useTP && !useSL) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   // AN TOAN (da sua lai dung theo nguoi dung chi ra): lenh Hedge (Section 11.3, mo boi
   // CheckHedgeZoneTrigger) luon mo CUNG CHIEU voi chuoi dang THANG THE tai thoi diem kich
   // hoat - tuc la mo NGUOC CHIEU voi chinh chuoi dang CAN duoc ho tro (chuoi yeu hon). Vi
   // vay khi chuoi X dang duong len, lenh Hedge lien quan (neu co) thuong la lenh NGUOC
   // CHIEU voi X (vi no duoc mo de "tang toc" cho phia doi dien luc chuoi X con la phia
   // yeu) - va thuong dang LO khi X dang lai (gia di thuan cho X = nghich cho Hedge nguoc
   // chieu). GOP (tru bot) khoan lo Hedge nguoc chieu do vao lai/lo cua chuoi X khi xet
   // Money TP/SL, dung y nguoi dung: "Tong lai = lai chuoi - lo Hedge, du $50 (nhu set) thi
   // dong LUON CA chuoi dang duong VA lenh Hedge nguoc chieu do" - giup "giai cuu" lenh
   // Hedge (thuong Lot lon, de mac o vung gia cuc tri) ngay khi phia doi dien du loi bu dap.
   double hedgeAddOn = (g_hedge.active && g_hedge.direction == -direction) ? GetHedgeProfit() : 0.0;
   double effProfit  = seq.sequenceProfit + hedgeAddOn;

   if(useTP)
     {
      double target = tpPct ? (bal * tpVal / 100.0) : tpVal;
      if(effProfit >= target)
        {
         PrintFormat("[Huuoaifx DCA] Target Profit (%s) dat %.2f (Chuoi %.2f - Hedge nguoc chieu %.2f) >= %.2f -> Dong chuoi (+ Hedge nguoc chieu neu co).",
                     (direction == 1 ? "BUY" : "SELL"), effProfit, seq.sequenceProfit, hedgeAddOn, target);
         CloseAllOrdersInSequence(seq); // Ham nay tu dong dong LUON lenh Hedge nguoc chieu (xem Section 9.1c)
         seq.recoveryCycle = 0;
         SyncSequenceFromPositions();
         return;
        }
     }
   if(useSL)
     {
      double target = slPct ? (bal * slVal / 100.0) : slVal;
      if(effProfit <= -target)
        {
         PrintFormat("[Huuoaifx DCA] Target Risk (%s) cham %.2f (Chuoi %.2f - Hedge nguoc chieu %.2f) <= -%.2f -> Dong chuoi (+ Hedge nguoc chieu neu co).",
                     (direction == 1 ? "BUY" : "SELL"), effProfit, seq.sequenceProfit, hedgeAddOn, target);
         CloseAllOrdersInSequence(seq);
         SyncSequenceFromPositions();
        }
     }
  }

// Loi nhuan bac thang: sau khi loi nhuan dat InpStepProfitStart, "dinh" (peak)
// duoc chot tron theo tung buoc InpStepProfitStepSize; neu loi nhuan tut xuong
// duoi (dinh da chot - InpStepProfitGiveback) -> khoa loi bang cach dong chuoi.
void EvaluateStepProfitLock(SSequenceState &seq, const int direction)
  {
   if(!InpUseStepProfit) return;
   if(!seq.active) return;
   if(seq.peakProfit < InpStepProfitStart) return;

   double stepSize = MathMax(InpStepProfitStepSize, 0.01);
   double stepsClimbed = MathFloor((seq.peakProfit - InpStepProfitStart) / stepSize);
   double stairPeak = InpStepProfitStart + stepsClimbed * stepSize;
   double closeTrigger = stairPeak - InpStepProfitGiveback;

   bool hit = (seq.sequenceProfit <= closeTrigger);

   // --- Bao ve Hedge nguoc chieu (Section 2.11, InpHedgeCloseMinProfit) - xem chi tiet
   //     tai HedgeCloseGuardBlocks(). Da cham nguong Giveback roi van CHUA dong neu chua du bu Hedge.
   if(hit && HedgeCloseGuardBlocks(seq, direction))
      hit = false;

   if(hit)
     {
      PrintFormat("[Huuoaifx DCA] Step Profit Lock (%s): dong chuoi tai loi nhuan %.2f (dinh da chot %.2f).",
                  (direction == 1 ? "BUY" : "SELL"), seq.sequenceProfit, stairPeak);
      CloseAllOrdersInSequence(seq);
      seq.recoveryCycle = 0;
      SyncSequenceFromPositions();
     }
  }

//----------------------------------------------------------------------
// 11.3z MUC TIEU LOI NHUAN BAC THANG (STAIRCASE TARGET, Section 2.15) - KHAC voi
//      Step Profit Lock (theo tung chuoi): day la moc LOI NHUAN TOAN TAI KHOAN
//      (hoac chi rieng EA neu InpStaircaseFilterMagicPair=true), lap lai nhieu
//      lan - moi khi Loi nhuan vuot 1 "bac" moi (boi so tiep theo cua
//      InpStaircaseTargetMoney), EA dong het lenh 1 lan, ghi nhan bac da dat,
//      va cho InpStaircaseCloseDelayMin phut truoc khi cho phep bac tiep theo.
//----------------------------------------------------------------------
void CheckStaircaseTarget()
  {
   if(!InpUseStaircaseTarget) return;
   if(InpStaircaseCloseDelayMin > 0 && g_lastStaircaseCloseTime > 0 &&
      (TimeCurrent() - g_lastStaircaseCloseTime) < InpStaircaseCloseDelayMin * 60) return;

   double totalProfit;
   if(InpStaircaseFilterMagicPair)
      totalProfit = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + GetHedgeProfit() + GetHedgeZoneProfit();
   else
      totalProfit = AccountInfoDouble(ACCOUNT_PROFIT);

   if(totalProfit < InpStaircaseTargetMoney) return; // Chua dat du 1 bac dau tien

   double rung = MathFloor(totalProfit / InpStaircaseTargetMoney) * InpStaircaseTargetMoney;
   if(rung <= g_staircaseLastRung) return; // Bac nay da xu ly roi

   PrintFormat("[Huuoaifx DCA] Muc tieu Loi nhuan Bac thang: Loi nhuan %.2f da vuot bac %.2f -> Dong toan bo.",
               totalProfit, rung);

   if(InpStaircaseFilterMagicPair)
      CloseAllEAOrders();
   else
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         trade.PositionClose(ticket);
        }
     }

   g_staircaseLastRung = rung;
   g_lastStaircaseCloseTime = TimeCurrent();
   g_buySeq.recoveryCycle = 0; g_sellSeq.recoveryCycle = 0;
   SyncSequenceFromPositions();
  }

//----------------------------------------------------------------------
// 11.4b DYNAMIC EMERGENCY TP (DIEU CHINH TP THEO DRAWDOWN) - Khi Drawdown
//      noi tai cua 1 chuoi (sequenceProfit am) vuot nguong InpAdjustNegativePercent/
//      InpAdjustNegativeMoney (Money hoac % Balance), EA "ha muc tieu" xuong 1 TP NHO HON tinh tu Gia
//      Trung Binh (InpAdjustedTP_Pips) de uu tien thoat Hoa/Loi nho, thay vi
//      cho doi TP goc (thuong xa hon va rui ro cao hon khi chuoi da DCA sau).
//----------------------------------------------------------------------
void EvaluateEmergencyTP(SSequenceState &seq, const int direction)
  {
   if(!InpUseEmergencyTP) return;
   if(!seq.active) return;

   if(!seq.emergencyActive)
     {
      // 2 nguong DOC LAP, moi nguong co the tu bat/tat rieng bang cach de = 0 (OFF):
      // Phan tram am (% Balance) VA/HOAC So tien am (Money) - CHI 1 trong 2 vuot la du kich hoat.
      bool hitPercent = (InpAdjustNegativePercent < 0.0) &&
                         (seq.sequenceProfit <= AccountInfoDouble(ACCOUNT_BALANCE) * InpAdjustNegativePercent / 100.0);
      bool hitMoney    = (InpAdjustNegativeMoney < 0.0) && (seq.sequenceProfit <= InpAdjustNegativeMoney);
      if(!hitPercent && !hitMoney) return;

      seq.emergencyActive = true;
      PrintFormat("[Huuoaifx DCA] Dieu chinh TP khi Am (%s): Loi nhuan chuoi %.2f da vuot nguong am -> Ha TP xuong %.1f pips tinh tu Gia TB.",
                  (direction == 1 ? "BUY" : "SELL"), seq.sequenceProfit, InpAdjustedTP_Pips);
     }

   double curPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double target    = NormalizePriceValue(seq.avgPrice + direction * PipsToPrice(InpAdjustedTP_Pips));

   bool hit = (direction == 1) ? (curPrice >= target) : (curPrice <= target);

   // --- Bao ve Hedge nguoc chieu (Section 2.11, InpHedgeCloseMinProfit) - xem chi tiet
   //     tai HedgeCloseGuardBlocks(). Da hit Pips roi van CHUA dong neu chua du bu Hedge.
   if(hit && HedgeCloseGuardBlocks(seq, direction))
      hit = false;

   if(hit)
     {
      PrintFormat("[Huuoaifx DCA] Emergency TP (%s): dat gia %s -> Dong chuoi (thoat uu tien an toan).",
                  (direction == 1 ? "BUY" : "SELL"), DoubleToString(target, g_sym.digits));
      CloseAllOrdersInSequence(seq);
      seq.recoveryCycle = 0;
      SyncSequenceFromPositions();
     }
  }

//----------------------------------------------------------------------
// 11.4c TP CHUOI DCA CO BAN (CHAIN TP) - Muc tieu chot toan bo chuoi tinh tu
//       Gia Trung Binh + InpChainTP_Pips (hoac InpResetChainTP_Pips neu chuoi dang
//       o che do "manualResetActive" sau khi bam nut HUD [Reset Lots]). Day la co
//       che THOAT CO BAN cua ca he thong Grid/DCA - chi tam dung khi chuoi dang
//       duoc 1 co che TP khac uu tien hon (Post-Trim TP / Dieu chinh TP khi Am) xu ly.
//----------------------------------------------------------------------
void EvaluateChainTP(SSequenceState &seq, const int direction)
  {
   if(!seq.active) return;
   if(seq.postTrimActive || seq.emergencyActive) return; // Nhuong cho TP uu tien hon

   // Trend Switch (Section 9.2c): chuoi dang "duoi xu huong" (dang pyramiding thuan) thi
   // MIEN TRU khoi TP chuoi theo Pip co dinh nay - muc dich Trend Switch la giu nguyen lai
   // va chay tiep theo xu huong, chi dong khi CHINH Trend Switch tu huy (tin hieu dao chieu
   // tro lai / ADX yeu) hoac Step Profit Lock giat lui tu dinh - khong de 1 nguong Pip co
   // dinh cat ngang som, pha vo dung y "giu toan bo lai" cua tinh nang.
   if(InpUseTrendSwitch && ((direction == 1 && g_trendSwitchState == 1) || (direction == -1 && g_trendSwitchState == -1)))
      return;

   // --- Dynamic Chain TP (UPGRADE moi, Section 2.4): sau khi chuoi da nhoi du
   //     InpDynamicTPStartOrder lenh, "ha" muc tieu TP chuoi xuong con
   //     InpDynamicTPReducedPips (thuong rat gan Gia Trung Binh, gan nhu Hoa Von) thay vi
   //     InpChainTP_Pips ban dau - uu tien THOAT SOM khi chuoi da qua nhieu lenh (rui ro
   //     cao), tranh phai cho doi TP xa trong luc DCA da qua sau. Uu tien THAP HON
   //     manualResetActive (nut HUD [Reset Lots] van giu nguyen y nghia rieng cua no).
   double tpPips;
   if(seq.manualResetActive)
      tpPips = InpResetChainTP_Pips;
   else if(InpUseDynamicChainTP && seq.totalOrders >= InpDynamicTPStartOrder)
      tpPips = InpDynamicTPReducedPips;
   else
      tpPips = InpChainTP_Pips;
   if(tpPips <= 0.0)
     {
      RemoveChainTPLine(direction);
      return;
     }

   double curPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double target    = NormalizePriceValue(seq.avgPrice + direction * PipsToPrice(tpPips));

   if(InpShowVirtualTP_Line) DrawChainTPLine(direction, target);
   else                       RemoveChainTPLine(direction);

   bool hit = (direction == 1) ? (curPrice >= target) : (curPrice <= target);

   // --- Bao ve Hedge nguoc chieu (Section 2.11, InpHedgeCloseMinProfit) - xem chi tiet
   //     tai HedgeCloseGuardBlocks(). Da hit Pips roi van CHUA dong neu chua du bu Hedge.
   if(hit && HedgeCloseGuardBlocks(seq, direction))
      hit = false;

   if(hit)
     {
      PrintFormat("[Huuoaifx DCA] TP chuoi DCA (%s): dat gia %s -> Dong toan bo chuoi.",
                  (direction == 1 ? "BUY" : "SELL"), DoubleToString(target, g_sym.digits));
      CloseAllOrdersInSequence(seq);
      seq.recoveryCycle = 0;
      RemoveChainTPLine(direction);
      SyncSequenceFromPositions();
     }
  }

void DrawChainTPLine(const int direction, const double price)
  {
   string name = HUD_PREFIX + "CHAINTP_" + (direction == 1 ? "BUY" : "SELL");
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
     }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT, StringFormat("TP chuoi %s: %s", (direction == 1 ? "BUY" : "SELL"), DoubleToString(price, g_sym.digits)));
  }

void RemoveChainTPLine(const int direction)
  {
   string name = HUD_PREFIX + "CHAINTP_" + (direction == 1 ? "BUY" : "SELL");
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
  }

// --- Lots toi da / chuoi (Section 2.2): khi InpNewCycleAtMaxLot=true va chuoi da cham
//     InpMaxTotalLot, tu dong dong het chuoi de "mo Chu ky moi" (thay vi chi dung DCA them).
void CheckMaxLotNewCycle(SSequenceState &seq, const int direction)
  {
   if(!InpNewCycleAtMaxLot || InpMaxTotalLot <= 0.0) return;
   if(!seq.active || seq.totalLot < InpMaxTotalLot) return;

   PrintFormat("[Huuoaifx DCA] Lots toi da (%s): Tong Lot %.2f da dat gioi han %.2f -> Dong chuoi de mo Chu ky moi.",
               (direction == 1 ? "BUY" : "SELL"), seq.totalLot, InpMaxTotalLot);
   CloseAllOrdersInSequence(seq);
   seq.recoveryCycle = 0;
   SyncSequenceFromPositions();
  }

// --- Che do Xo So: "So tien cat lo va reset chuoi xo so" (InpLotteryCutLossReset, 0->OFF) -
//     luoi an toan doc lap voi Target: khi 1 chuoi lo cham nguong nay, dong ngay va RESET
//     han lotteryStage ve 0 (khong tinh la 1 lan SL de nhan don compounding tiep).
void CheckLotteryCutLoss(SSequenceState &seq, const int direction)
  {
   if(!InpEnableLotteryMode || InpLotteryCutLossReset <= 0.0) return;
   if(!seq.active) return;
   if(seq.sequenceProfit > -MathAbs(InpLotteryCutLossReset)) return;

   PrintFormat("[Huuoaifx DCA] Xo So - Cat lo & Reset (%s): Loi nhuan chuoi %.2f cham nguong -%.2f -> Dong chuoi va Reset He so nhan.",
               (direction == 1 ? "BUY" : "SELL"), seq.sequenceProfit, InpLotteryCutLossReset);
   CloseAllOrdersInSequence(seq);
   seq.recoveryCycle = 0;
   SyncSequenceFromPositions();
   if(direction == 1) g_buySeq.lotteryStage = 0; else g_sellSeq.lotteryStage = 0;
  }

//----------------------------------------------------------------------
// 11.5 TIME FILTER - Kiem tra 4 khung gio giao dich (tinh theo GIO MAY
//      TINH/LAPTOP dang chay EA - TimeLocal(), KHONG phai gio Server).
//----------------------------------------------------------------------
bool IsWithinTradingSession()
  {
   if(!InpUseTimeFilter) return(true);

   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   int nowMinutes = dt.hour * 60 + dt.min;

   for(int i = 0; i < 4; i++)
     {
      if(!g_sessions[i].enabled || !g_sessions[i].valid) continue;

      int startM = g_sessions[i].startHour * 60 + g_sessions[i].startMinute;
      int endM   = g_sessions[i].endHour * 60 + g_sessions[i].endMinute;

      if(startM <= endM)
        {
         if(nowMinutes >= startM && nowMinutes < endM) return(true);
        }
      else
        {
         // Khung gio qua nua dem (vd 22:00 -> 05:00)
         if(nowMinutes >= startM || nowMinutes < endM) return(true);
        }
     }
   return(false);
  }

//----------------------------------------------------------------------
// 11.6 TRAILING STOP CHUOI DCA - Truot 1 muc Stop chung cho CA CHUOI (tinh
//      tu Gia Trung Binh cua chuoi, khong phai tung lenh le), kich hoat khi
//      loi nhuan dat InpTrailingTriggerPips, sau do doi SL theo tung buoc
//      InpTrailingStepPips va giu khoang cach InpTrailingStopPips voi gia.
//      Ve them 1 duong ke ngang (OBJ_HLINE) the hien muc Stop dang chay.
//----------------------------------------------------------------------
void DrawTrailingLine(const int direction, const double price)
  {
   string name = HUD_PREFIX + "TRAIL_" + (direction == 1 ? "BUY" : "SELL");
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpTrailingLineColor);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT,
                    StringFormat("Trailing Stop %s: %s", (direction == 1 ? "BUY" : "SELL"), DoubleToString(price, g_sym.digits)));
  }

void RemoveTrailingLine(const int direction)
  {
   string name = HUD_PREFIX + "TRAIL_" + (direction == 1 ? "BUY" : "SELL");
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
  }

void ManageTrailingStop(SSequenceState &seq, const int direction)
  {
   if(!InpUseTrailingStop)
     {
      if(seq.trailingStopPrice > 0.0) { seq.trailingStopPrice = 0.0; RemoveTrailingLine(direction); }
      return;
     }
   if(!seq.active)
     {
      if(seq.trailingStopPrice > 0.0) { seq.trailingStopPrice = 0.0; RemoveTrailingLine(direction); }
      return;
     }

   double curPrice   = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitPips = PriceToPips((curPrice - seq.avgPrice) * direction);

   // Chua tung kich hoat (trailingStopPrice==0) VA chua dat nguong kich hoat -> chua lam gi ca
   if(seq.trailingStopPrice <= 0.0 && profitPips < InpTrailingTriggerPips)
      return;

   double stepPrice = PipsToPrice(MathMax(InpTrailingStepPips, 0.1));
   double distPrice = PipsToPrice(MathMax(InpTrailingStopPips, 0.1));
   if(stepPrice <= 0.0) stepPrice = g_sym.point;
   if(distPrice <= 0.0) distPrice = g_sym.point;

   bool isFirstActivation = (seq.trailingStopPrice <= 0.0); // Lan dau kich hoat Trailing cho chuoi nay
   // Lan dau kich hoat dung khoang cach rieng InpTrailingFirstSLPips (thuong GAN
   // hon, uu tien bao ve von ngay) - tu lan thu 2 tro di dung InpTrailingStopPips.
   double firstDistPrice = PipsToPrice(InpTrailingFirstSLPips);
   double useDistPrice   = (isFirstActivation && firstDistPrice > 0.0) ? firstDistPrice : distPrice;

   // Tinh muc Stop "ung vien" tai gia hien tai: xuat phat tu diem kich hoat
   // (avgPrice + Trigger), lam tron phan gia da di THEM duoc ve boi so buoc
   // Step tron -> tao hieu ung "bac thang" (khong truot lien tuc tung tick).
   double armPrice = seq.avgPrice + direction * PipsToPrice(InpTrailingTriggerPips);
   double advance  = (curPrice - armPrice) * direction;
   if(advance < 0.0) advance = 0.0;
   double steppedAdvance = MathFloor(advance / stepPrice) * stepPrice;
   double candidateStop  = armPrice + direction * steppedAdvance - direction * useDistPrice;

   bool improves = (seq.trailingStopPrice <= 0.0) ||
                   (direction == 1  && candidateStop > seq.trailingStopPrice) ||
                   (direction == -1 && candidateStop < seq.trailingStopPrice);

   if(improves && profitPips >= InpTrailingTriggerPips)
     {
      seq.trailingStopPrice = NormalizePriceValue(candidateStop);
      if(InpShowTrailingLine) DrawTrailingLine(direction, seq.trailingStopPrice);
      else                    RemoveTrailingLine(direction);
     }

   if(seq.trailingStopPrice > 0.0)
     {
      bool hit = (direction == 1 && curPrice <= seq.trailingStopPrice) ||
                 (direction == -1 && curPrice >= seq.trailingStopPrice);

      // --- Bao ve Hedge nguoc chieu (Section 2.11, InpHedgeCloseMinProfit) - xem chi tiet
      //     tai HedgeCloseGuardBlocks(). Da cham Trailing Stop roi van CHUA dong neu chua du
      //     bu Hedge - GIU NGUYEN muc Trailing Stop hien tai (khong reset ve 0), chi tam
      //     hoan dong, cho gia tiep tuc hoac Hedge tu xu ly rieng (ManageHedgePosition).
      if(hit && HedgeCloseGuardBlocks(seq, direction))
         hit = false;

      if(hit)
        {
         PrintFormat("[Huuoaifx DCA] Trailing Stop (%s): dong chuoi tai gia %s (muc Stop %s).",
                     (direction == 1 ? "BUY" : "SELL"), DoubleToString(curPrice, g_sym.digits),
                     DoubleToString(seq.trailingStopPrice, g_sym.digits));
         CloseAllOrdersInSequence(seq);
         seq.recoveryCycle = 0;
         seq.trailingStopPrice = 0.0;
         RemoveTrailingLine(direction);
         SyncSequenceFromPositions();
        }
     }
  }

//----------------------------------------------------------------------
// 11.7 TARGET LOI NHUAN NGAY (DAILY PROFIT TARGET) - Theo doi hieu qua
//      giao dich trong 1 NGAY (tinh theo Server Time, moc 00:00), dua tren
//      bien dong Equity so voi luc bat dau ngay. Khi dat Target va bat
//      InpStopTradingOnDailyTarget: NGUNG mo Chuoi moi / NGUNG DCA them
//      trong phan con lai cua ngay (KHONG tu dong dong cac lenh dang mo).
//----------------------------------------------------------------------
void CheckDailyReset()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStamp = StructToTime(dt);

   if(todayStamp != g_dailyDayStamp && todayStamp != g_dailyPendingStamp)
      g_dailyPendingStamp = todayStamp; // Vua phat hien Ngay moi -> cho InpDailyNewDayDelayMin truoc khi Reset

   // Chi thuc su Reset baseline Ngay sau khi da qua du InpDailyNewDayDelayMin phut
   // tinh tu 00:00 (tranh Reset dung luc dem giao dich, gay sai lech Target/Loss Limit).
   if(g_dailyPendingStamp != 0 && g_dailyPendingStamp != g_dailyDayStamp &&
      TimeCurrent() >= g_dailyPendingStamp + InpDailyNewDayDelayMin * 60)
     {
      // --- UPGRADE (sua loi): neu con 1 chuoi dang hoat dong (chua dong sach ca 2 ben),
      //     KHONG duoc reset lai moc Baseline Ngay (g_dailyStartEquity/g_dailyStartBalance)
      //     - giu nguyen moc CU cho den khi ca 2 chuoi dong het (Flat) moi thuc su Reset.
      //     Neu khong, 1 chuoi dang am nang bi "quy ve moc 0" ngay dau ngay moi, khien
      //     Target Loi Nhuan Ngay / Gioi han Thua Lo Ngay tinh sai hoan toan huong lai/lo
      //     THUC SU cua chuoi do. g_dailyPendingStamp duoc GIU NGUYEN nen dieu kien nay se
      //     duoc kiem tra lai o moi lan goi tiep theo, tu dong Reset ngay khi thuc su Flat.
      if(g_buySeq.active || g_sellSeq.active) return;

      g_dailyDayStamp       = g_dailyPendingStamp;
      g_dailyStartEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dailyStartBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyTargetHitToday = false;
      g_dailyLossHitToday   = false;
      PrintFormat("[Huuoaifx DCA] Ngay giao dich moi (Server Time) - Equity dau ngay: %.2f, Balance dau ngay: %.2f",
                  g_dailyStartEquity, g_dailyStartBalance);
     }
  }

// Loi nhuan DA CHOT (realized) trong ngay hien tai - dua tren bien dong Balance
// (khac voi Daily Profit Target o tren dung Equity, vi Cross-Sequence Trim can
// biet chinh xac so tien DA THUC SU vao tui, khong tinh phan dang con Floating).
double GetDailyRealizedProfit()
  {
   return(AccountInfoDouble(ACCOUNT_BALANCE) - g_dailyStartBalance);
  }

// Target Loi nhuan Ngay VA Gioi han thua lo Ngay - 2 dieu kien DOC LAP (OR),
// chi 1 trong 2 dat la du de Dung mo Chuoi moi/DCA them trong phan con lai
// cua ngay (xem InpStopTradingOnDailyTarget o noi goi ham nay).
bool IsDailyTargetReached()
  {
   if(!InpUseDailyTarget) return(false);
   if(g_dailyStartEquity <= 0.0) return(false);

   double dailyProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;
   double target = InpDailyTarget_IsPercent ? (g_dailyStartEquity * InpDailyTarget_PercentValue / 100.0) : InpDailyTarget_Value;

   bool hitTarget = (target > 0.0) && (dailyProfit >= target);
   if(hitTarget && !g_dailyTargetHitToday)
     {
      g_dailyTargetHitToday = true;
      PrintFormat("[Huuoaifx DCA] Da dat Target Loi nhuan Ngay: %.2f >= %.2f.", dailyProfit, target);
     }

   // Gioi han thua lo Ngay: 2 nguong DOC LAP, moi nguong co the tu tat rieng (=0 -> OFF)
   bool hitLossMoney   = (InpDailyLossLimit != 0.0) && (dailyProfit <= -MathAbs(InpDailyLossLimit));
   bool hitLossPercent = (InpDailyLossLimitPercent != 0.0) &&
                          (dailyProfit <= -MathAbs(g_dailyStartEquity * InpDailyLossLimitPercent / 100.0));
   bool hitLoss = hitLossMoney || hitLossPercent;
   if(hitLoss && !g_dailyLossHitToday)
     {
      g_dailyLossHitToday = true;
      PrintFormat("[Huuoaifx DCA] Da cham Gioi han thua lo Ngay: %.2f.", dailyProfit);
     }

   return(hitTarget || hitLoss);
  }

//----------------------------------------------------------------------
// 11.8 MAX FLOATING DRAWDOWN TRACKING - Theo doi Dinh Equity cao nhat va
//      muc Drawdown noi (chua chot loi) lon nhat tung xay ra trong PHIEN
//      EA DANG CHAY (reset ve 0 moi lan gan lai EA, khong luu qua file).
//----------------------------------------------------------------------
void UpdateMaxDrawdownTracking()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity)
     {
      g_peakEquity = eq;
      return;
     }

   double ddMoney   = g_peakEquity - eq;
   double ddPercent = (g_peakEquity > 0.0) ? (ddMoney / g_peakEquity * 100.0) : 0.0;

   if(ddMoney > g_maxFloatingDD_Money)
     {
      g_maxFloatingDD_Money   = ddMoney;
      g_maxFloatingDD_Percent = ddPercent;
     }
  }

//----------------------------------------------------------------------
// 11.9 CHE DO XO SO (LOTTERY / HIGH-RISK MODE) - Khi bat, moi lenh moi
//      (Entry/DCA) duoc nhan them InpLotteryLotMultiplier de tang toc do
//      dat Target (xem OpenNewOrder). Khi Equity dat dung InpLotteryTargetMultiplier
//      lan Equity luc bat dau, EA tu dong dong toan bo lenh va TU NGAT (ExpertRemove).
//----------------------------------------------------------------------
void CheckLotteryTarget()
  {
   if(!InpEnableLotteryMode || g_lotteryTargetHit) return;
   if(g_lotteryStartEquity <= 0.0) return;

   double target = g_lotteryStartEquity * InpLotteryTargetMultiplier;
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq < target) return;

   g_lotteryTargetHit = true;
   PrintFormat("[Huuoaifx DCA] XO SO MODE: Equity %.2f da dat Target x%.2f (%.2f) -> Dong toan bo lenh va NGAT EA.",
               eq, InpLotteryTargetMultiplier, target);
   CloseAllEAOrders();
   ObjectsDeleteAll(0, HUD_PREFIX);
   Comment("");
   ExpertRemove();
  }

//======================================================================
// 12. DASHBOARD (HUD) - Ve bang thong tin gon tren Chart bang OBJ_LABEL,
//     tu dong don dep khi so dong thay doi. Khong co dong chu ban quyen.
//======================================================================
void AddDashboardLine(string &lines[], color &colors[], int &n, const string text, const color clr)
  {
   if(n >= ArraySize(lines))
     {
      ArrayResize(lines, n + 8);
      ArrayResize(colors, n + 8);
     }
   lines[n] = text;
   colors[n] = clr;
   n++;
  }

void RenderDashboard(const string &lines[], const color &colors[])
  {
   int n = ArraySize(lines);
   int lineHeight = InpDashboardFontSize + 6;
   int panelW = 300;
   int panelH = n * lineHeight + 10;

   string bgName = HUD_PREFIX + "BG";
   if(ObjectFind(0, bgName) < 0)
     {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, InpDashboardCorner);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpDashboardX - 6);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpDashboardY - 6);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpDashboardColorBG);

   for(int i = 0; i < n; i++)
     {
      string name = HUD_PREFIX + "L" + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
        }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashboardX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashboardY + i * lineHeight);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashboardFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
     }

   // Xoa cac dong thua tu lan ve truoc (khi so dong giam di)
   int idx = n;
   while(true)
     {
      string name = HUD_PREFIX + "L" + IntegerToString(idx);
      if(ObjectFind(0, name) < 0) break;
      ObjectDelete(0, name);
      idx++;
     }

   ChartRedraw(0);
  }

void UpdateDashboard()
  {
   if(!InpShowDashboard)
     {
      ObjectsDeleteAll(0, HUD_PREFIX);
      return;
     }

   string lines[]; color colors[]; int n = 0;
   ArrayResize(lines, 12); ArrayResize(colors, 12);

   AddDashboardLine(lines, colors, n,
                     StringFormat("%s  |  %s", _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period)),
                     InpDashboardColorText);
   AddDashboardLine(lines, colors, n,
                     StringFormat("Balance: %.2f   Equity: %.2f", AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)),
                     InpDashboardColorText);

   double totalFloating = g_buySeq.sequenceProfit + g_sellSeq.sequenceProfit + GetHedgeProfit();
   AddDashboardLine(lines, colors, n, StringFormat("Floating P/L: %.2f", totalFloating),
                     (totalFloating >= 0 ? InpDashboardColorProfit : InpDashboardColorLoss));

   if(g_maxFloatingDD_Money > 0.0)
      AddDashboardLine(lines, colors, n,
                        StringFormat("Max Floating DD: -%.2f (-%.2f%%)", g_maxFloatingDD_Money, g_maxFloatingDD_Percent),
                        InpDashboardColorLoss);

   if(g_manualStopBuy || g_manualStopSell)
      AddDashboardLine(lines, colors, n,
                        StringFormat("STOP (Thu cong): Buy=%s  Sell=%s", (g_manualStopBuy ? "ON" : "-"), (g_manualStopSell ? "ON" : "-")),
                        InpDashboardColorLoss);

   AddDashboardLine(lines, colors, n, "------------------------------", InpDashboardColorText);

   AddDashboardLine(lines, colors, n,
                     StringFormat("BUY  [%s] Lenh:%d  Lot:%.2f  TB:%s",
                                   (g_buySeq.active ? "ON " : "OFF"), g_buySeq.totalOrders, g_buySeq.totalLot,
                                   DoubleToString(g_buySeq.avgPrice, g_sym.digits)),
                     (g_buySeq.active ? InpDashboardColorText : clrGray));
   AddDashboardLine(lines, colors, n,
                     StringFormat("     P/L: %.2f   Recovery: %d/%d", g_buySeq.sequenceProfit,
                                   g_buySeq.recoveryCycle, InpSLRecoveryMaxCycles),
                     (g_buySeq.sequenceProfit >= 0 ? InpDashboardColorProfit : InpDashboardColorLoss));

   AddDashboardLine(lines, colors, n,
                     StringFormat("SELL [%s] Lenh:%d  Lot:%.2f  TB:%s",
                                   (g_sellSeq.active ? "ON " : "OFF"), g_sellSeq.totalOrders, g_sellSeq.totalLot,
                                   DoubleToString(g_sellSeq.avgPrice, g_sym.digits)),
                     (g_sellSeq.active ? InpDashboardColorText : clrGray));
   AddDashboardLine(lines, colors, n,
                     StringFormat("     P/L: %.2f   Recovery: %d/%d", g_sellSeq.sequenceProfit,
                                   g_sellSeq.recoveryCycle, InpSLRecoveryMaxCycles),
                     (g_sellSeq.sequenceProfit >= 0 ? InpDashboardColorProfit : InpDashboardColorLoss));

   if(InpUseHedging)
      AddDashboardLine(lines, colors, n,
                        (g_hedge.active ? StringFormat("HEDGE [%s] Lot:%.2f  P/L:%.2f",
                                                        (g_hedge.direction == 1 ? "BUY " : "SELL"), g_hedge.lot, GetHedgeProfit())
                                        : "HEDGE [Khong hoat dong]"),
                        InpDashboardColorText);

   if(InpUseHedgingZone)
      AddDashboardLine(lines, colors, n,
                        (g_hedgeZone.active ? StringFormat("HEDGE ZONE [%s] Lot:%.2f  P/L:%.2f",
                                                            (g_hedgeZone.direction == 1 ? "BUY " : "SELL"), g_hedgeZone.lot, GetHedgeZoneProfit())
                                            : "HEDGE ZONE [Khong hoat dong]"),
                        InpDashboardColorText);

   if(InpUseOppositeOrder && (g_oppBuy.active || g_oppSell.active))
      AddDashboardLine(lines, colors, n,
                        StringFormat("OPPOSITE  Buy:%s  Sell:%s",
                                      (g_oppBuy.active  ? StringFormat("%.2f lot", g_oppBuy.lot)  : "-"),
                                      (g_oppSell.active ? StringFormat("%.2f lot", g_oppSell.lot) : "-")),
                        InpDashboardColorText);

   if(InpEnableLotteryMode)
      AddDashboardLine(lines, colors, n,
                        StringFormat("XO SO (Lottery)  Stage Buy:%d  Sell:%d", g_buySeq.lotteryStage, g_sellSeq.lotteryStage),
                        InpDashboardColorText);

   if(InpUseStaircaseTarget)
      AddDashboardLine(lines, colors, n,
                        StringFormat("BAC THANG  Da chot: %.0f  (Muc tieu moi: %.0f)",
                                      g_staircaseLastRung, g_staircaseLastRung + InpStaircaseTargetMoney),
                        InpDashboardColorText);

   if(InpUseLotEqualizer)
      AddDashboardLine(lines, colors, n,
                        (g_equalizer.active ? StringFormat("EQUALIZER [%s] Lot:%.2f", (g_equalizer.direction == 1 ? "BUY " : "SELL"), g_equalizer.lot)
                                             : StringFormat("EQUALIZER [Idle] Chenh Lot: %.2f", MathAbs(g_buySeq.totalLot - g_sellSeq.totalLot))),
                        InpDashboardColorText);

   if(InpUseAdvancedTrim || InpUsePartialTrim || InpUseCrossSequenceTrim)
      AddDashboardLine(lines, colors, n,
                        StringFormat("TRIM  Buy:%d(%s)  Sell:%d(%s)",
                                      g_buySeq.trimCount, (g_buySeq.postTrimActive ? (g_buySeq.partialTrimMode ? "PostTP-1P" : "PostTP") : "-"),
                                      g_sellSeq.trimCount, (g_sellSeq.postTrimActive ? (g_sellSeq.partialTrimMode ? "PostTP-1P" : "PostTP") : "-")),
                        InpDashboardColorText);

   if(g_buySeq.manualResetActive || g_sellSeq.manualResetActive)
      AddDashboardLine(lines, colors, n,
                        StringFormat("RESET LOTS: Buy=%s  Sell=%s", (g_buySeq.manualResetActive ? "ON" : "-"), (g_sellSeq.manualResetActive ? "ON" : "-")),
                        InpDashboardColorText);

   if(InpUseEmergencyTP && (g_buySeq.emergencyActive || g_sellSeq.emergencyActive))
      AddDashboardLine(lines, colors, n,
                        StringFormat("EMERGENCY TP: Buy=%s  Sell=%s",
                                      (g_buySeq.emergencyActive ? "ON" : "-"), (g_sellSeq.emergencyActive ? "ON" : "-")),
                        InpDashboardColorLoss);

   if(InpUseTimeFilter)
     {
      bool sessionOk = IsWithinTradingSession();
      AddDashboardLine(lines, colors, n, StringFormat("Trading Session: %s", (sessionOk ? "MO" : "DONG")),
                        (sessionOk ? InpDashboardColorProfit : InpDashboardColorLoss));
     }

   if(InpUseDailyTarget)
     {
      double dailyProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;
      bool   dailyHit    = IsDailyTargetReached();
      AddDashboardLine(lines, colors, n, StringFormat("Daily P/L: %.2f  %s", dailyProfit, (dailyHit ? "[DA DAT TARGET]" : "")),
                        (dailyProfit >= 0 ? InpDashboardColorProfit : InpDashboardColorLoss));
     }

   if(InpUseTrailingStop && (g_buySeq.trailingStopPrice > 0.0 || g_sellSeq.trailingStopPrice > 0.0))
     {
      if(g_buySeq.trailingStopPrice > 0.0)
         AddDashboardLine(lines, colors, n, StringFormat("Trailing BUY Stop: %s", DoubleToString(g_buySeq.trailingStopPrice, g_sym.digits)), InpTrailingLineColor);
      if(g_sellSeq.trailingStopPrice > 0.0)
         AddDashboardLine(lines, colors, n, StringFormat("Trailing SELL Stop: %s", DoubleToString(g_sellSeq.trailingStopPrice, g_sym.digits)), InpTrailingLineColor);
     }

   ArrayResize(lines, n);
   ArrayResize(colors, n);
   RenderDashboard(lines, colors);

   if(InpShowHudButtons)
      RenderHudButtons(n, InpDashboardFontSize + 6);
   else
     {
      ObjectDelete(0, HUD_PREFIX + "BTN_CLOSEBUY");
      ObjectDelete(0, HUD_PREFIX + "BTN_CLOSESELL");
      ObjectDelete(0, HUD_PREFIX + "BTN_RESETLOTS");
      ObjectDelete(0, HUD_PREFIX + "BTN_STOPBUY");
      ObjectDelete(0, HUD_PREFIX + "BTN_STOPSELL");
     }
  }

//----------------------------------------------------------------------
// 12.1 HUD BUTTONS (INTERACTIVE) - 5 nut bam tren Chart: Close Buy, Close
//      Sell, Reset Lots, Stop Buy, Stop Sell. Xu ly click thuc te o
//      OnChartEvent() (Section 15). Vi tri ve NGAY DUOI panel Dashboard.
//----------------------------------------------------------------------
void CreateOrUpdateHudButton(const string name, const string text, const int x, const int y,
                              const int w, const int h, const color bg)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, MathMax(InpDashboardFontSize - 1, 7));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

void RenderHudButtons(const int textLineCount, const int lineHeight)
  {
   int btnY  = InpDashboardY + textLineCount * lineHeight + 10;
   int btnH  = 22;
   int btnW  = 92;
   int gap   = 4;

   CreateOrUpdateHudButton(HUD_PREFIX + "BTN_CLOSEBUY",  "Close Buy",  InpDashboardX,                 btnY, btnW, btnH, clrFireBrick);
   CreateOrUpdateHudButton(HUD_PREFIX + "BTN_CLOSESELL", "Close Sell", InpDashboardX + (btnW + gap),   btnY, btnW, btnH, clrFireBrick);
   CreateOrUpdateHudButton(HUD_PREFIX + "BTN_RESETLOTS", "Reset Lots", InpDashboardX + 2*(btnW + gap), btnY, btnW, btnH, clrDarkOrange);

   int btnY2 = btnY + btnH + gap;
   CreateOrUpdateHudButton(HUD_PREFIX + "BTN_STOPBUY",
                            StringFormat("Stop Buy: %s",  g_manualStopBuy  ? "ON" : "OFF"),
                            InpDashboardX,               btnY2, btnW, btnH, g_manualStopBuy  ? clrFireBrick : clrDimGray);
   CreateOrUpdateHudButton(HUD_PREFIX + "BTN_STOPSELL",
                            StringFormat("Stop Sell: %s", g_manualStopSell ? "ON" : "OFF"),
                            InpDashboardX + (btnW + gap), btnY2, btnW, btnH, g_manualStopSell ? clrFireBrick : clrDimGray);

   ChartRedraw(0);
  }

//======================================================================
// 13. GRID/DCA ORCHESTRATION - Entry va DCA thuc te (goi Signal Engine +
//     Grid Engine cua Section 8-9 va gui lenh qua CTrade).
//======================================================================

// Mo 1 lenh thi truong (Entry hoac DCA) theo huong 'direction', tu dong xu ly
// Virtual TP/SL (an) hoac SL/TP that (gui thang len Broker) tuy InpUseVirtualTPSL.
bool OpenNewOrder(const int direction, double lot, const bool isDCA = false)
  {
   lot = NormalizeLotValue(lot);
   if(lot < g_sym.volumeMin) return(false);

   // --- Loc Spread toi da: khong mo lenh moi (Entry hoac DCA) khi Spread hien tai qua rong,
   //     tranh truot gia/vao lenh bat loi trong giai doan thi truong bien dong manh.
   if(InpMaxSpreadPips > 0.0)
     {
      double curSpreadPips = PriceToPips(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));
      if(curSpreadPips > InpMaxSpreadPips)
        {
         PrintFormat("[Huuoaifx DCA] Spread hien tai %.1f pips > InpMaxSpreadPips %.1f -> Huy mo lenh %s.",
                     curSpreadPips, InpMaxSpreadPips, (direction == 1 ? "BUY" : "SELL"));
         return(false);
        }
     }

   double price = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // --- TP don lenh: cac lenh DCA dung InpDCAOrderTP_Pips (neu >0) thay cho
   //     InpVirtualTP_Pips chung, cho phep TP rieng cho tung lenh nhoi.
   double effTP_Pips = (isDCA && InpDCAOrderTP_Pips > 0.0) ? InpDCAOrderTP_Pips : InpVirtualTP_Pips;

   double vSL = 0.0, vTP = 0.0;
   if(InpVirtualSL_Pips > 0) vSL = NormalizePriceValue(price - direction * PipsToPrice(InpVirtualSL_Pips));
   if(effTP_Pips > 0)        vTP = NormalizePriceValue(price + direction * PipsToPrice(effTP_Pips));

   double sendSL = 0.0, sendTP = 0.0;
   if(!InpUseVirtualTPSL) { sendSL = vSL; sendTP = vTP; } // Virtual TAT -> se PositionModify SL/TP that len Broker SAU KHI khop lenh (xem ben duoi)

   // --- SUA LOI TU CHOI LENH TREN SAN ECN (Fatal Bug #1): gui truc tiep SL/TP vao lenh
   //     Market (trade.Buy/Sell) se bi san ECN/STP tra ve loi 10016 (Invalid Stops), vi Gia
   //     SL/TP tinh truoc do co the da lech khoi Gia KHOP THUC TE (Requote/Slippage) ngay
   //     dung luc Broker doi chieu lenh - loai san nay KHONG cho phep gui SL/TP dinh kem
   //     lenh Market, BAT BUOC phai mo lenh TRUOC (voi sl=0.0, tp=0.0), roi moi dung lenh
   //     PositionModify() rieng de dan SL/TP that vao Position SAU KHI da khop thanh cong.
   bool ok = (direction == 1) ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, InpOrderComment)
                               : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, InpOrderComment);
   if(!ok)
     {
      PrintFormat("[Huuoaifx DCA] Loi mo lenh %s Lot=%.2f: %d - %s",
                  (direction == 1 ? "BUY" : "SELL"), lot, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return(false);
     }

   // --- Nut HUD [Reset Lots]: da dung InpManualResetLot cho lenh nay -> xoa co "force"
   //     1-lan, VA chuyen chuoi sang che do "manualResetActive" (dung He so nhan/TP rieng
   //     cho cac lenh DCA tiep theo trong CUNG chuoi nay - xem CalculateDCALot/EvaluateChainTP).
   if(direction == 1)
     {
      if(g_forceInitialLotBuy)  { g_buySeq.manualResetActive  = true; }
      g_forceInitialLotBuy  = false;
     }
   else
     {
      if(g_forceInitialLotSell) { g_sellSeq.manualResetActive = true; }
      g_forceInitialLotSell = false;
     }

   // --- Xac dinh Ticket Position that vua duoc tao (dung cho ca Virtual TP/SL VA
   //     PositionModify SL/TP that - Fatal Bug #1 o tren) - can khi (1) InpUseVirtualTPSL=true
   //     va co muc vSL/vTP, HOAC (2) InpUseVirtualTPSL=false va co sendSL/sendTP that can day
   //     len Broker qua PositionModify().
   //
   //     UPGRADE (sua loi, do bo an toan lay Position Ticket): KHONG chi dua vao gia
   //     dinh "Ticket Order vua khop = Ticket Position" (gia dinh nay co the SAI trong
   //     mot so tinh huong ECN/STP nhieu Deal, hoac San Hedging voi khop lenh dac
   //     biet). Thu tu uu tien AN TOAN: (1) Tra cuu qua DEAL_POSITION_ID cua chinh
   //     Deal vua khop (trade.ResultDeal()) - day la cach CHINH THONG MQL5 khuyen dung
   //     de biet chac Deal do thuoc/tao ra Position nao; (2) Fallback ve
   //     trade.ResultOrder() (dung voi lenh thi truong don gian, khong Requote/Partial
   //     Fill); (3) Fallback cuoi cung: neu 2 cach tren chua san sang, quet cac Position
   //     dang mo tren cung Symbol+Magic Number, chon Position MOI NHAT (POSITION_TIME
   //     lon nhat) - dam bao luon lay dung Ticket that de gan Virtual SL/TP / PositionModify.
   if((InpUseVirtualTPSL && (vSL > 0.0 || vTP > 0.0)) || (!InpUseVirtualTPSL && (sendSL > 0.0 || sendTP > 0.0)))
     {
      // --- Uu tien 1: trade.ResultPosition() - ham CTrade chuyen dung de lay dung Ticket
      //     Position vua duoc tao boi lenh Market vua goi (co san tu MQL5 build moi, danh
      //     tin cay nhat vi CTrade tu theo doi ket qua giao dich cua chinh no).
      ulong newTicket = trade.ResultPosition();
      // --- Uu tien 2: DEAL_POSITION_ID cua Deal vua khop (trade.ResultDeal()) - cach CHINH
      //     THONG MQL5 khuyen dung de biet chac Deal do thuoc/tao ra Position nao.
      if(newTicket == 0)
        {
         ulong dealTicket = trade.ResultDeal();
         if(dealTicket > 0 && HistoryDealSelect(dealTicket))
            newTicket = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
        }
      // --- Uu tien 3: trade.ResultOrder() (dung voi lenh thi truong don gian, khong
      //     Requote/Partial Fill).
      if(newTicket == 0)
         newTicket = trade.ResultOrder();
      if(newTicket == 0 || !PositionSelectByTicket(newTicket))
        {
         datetime newestTime = 0; ulong newestTicket = 0;
         for(int vi = 0; vi < PositionsTotal(); vi++)
           {
            ulong vt = PositionGetTicket(vi);
            if(vt == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            datetime vpt = (datetime)PositionGetInteger(POSITION_TIME);
            if(vpt >= newestTime) { newestTime = vpt; newestTicket = vt; }
           }
         if(newestTicket > 0) newTicket = newestTicket;
        }

      if(newTicket > 0)
        {
         if(InpUseVirtualTPSL && (vSL > 0.0 || vTP > 0.0))
            SetVirtualLevels(newTicket, vSL, vTP);

         // --- SUA LOI TU CHOI LENH TREN SAN ECN (Fatal Bug #1, tiep theo): sau khi da co
         //     Ticket that (newTicket > 0) VA Virtual TP/SL dang TAT (!InpUseVirtualTPSL) VA
         //     that su co SL/TP can dat (sendSL>0.0 || sendTP>0.0), moi goi PositionModify()
         //     de day SL/TP that len Broker - KHONG con gui kem trong lenh Market lúc Open nua.
         if(!InpUseVirtualTPSL && (sendSL > 0.0 || sendTP > 0.0))
           {
            if(!trade.PositionModify(newTicket, sendSL, sendTP))
               PrintFormat("[Huuoaifx DCA] Loi PositionModify SL/TP that cho lenh #%I64u (SL=%s, TP=%s): %d - %s",
                           newTicket, DoubleToString(sendSL, g_sym.digits), DoubleToString(sendTP, g_sym.digits),
                           trade.ResultRetcode(), trade.ResultRetcodeDescription());
           }
        }
     }

   SyncSequenceFromPositions();
   return(true);
  }

// Tinh Lot cho 1 lenh sap mo (Entry hoac DCA) cho huong 'direction', gop tat ca cac lop
// dieu chinh: Nut HUD Reset Lots (uu tien tuyet doi) -> He so nhan sau Reset/sau Tia ->
// Custom Lot Sequence (co "Lots toi thieu bang lenh truoc") -> Martingale SL Recovery ->
// Che do Xo So (He so nhan khi SL, theo seq.lotteryStage).
double ResolveOrderLot(const int direction, const SSequenceState &seq)
  {
   bool force = (direction == 1) ? g_forceInitialLotBuy : g_forceInitialLotSell;
   if(force) return(NormalizeLotValue(InpManualResetLot));

   int    lotIndex = GetLotIndexForNewOrder(direction);
   int    n        = ArraySize(seq.orders);
   double prevLot   = (n > 0) ? seq.orders[n - 1].lot : 0.0;

   double overrideMult = 0.0;
   if(seq.manualResetActive)     overrideMult = InpResetLotMultiplier;
   else if(seq.postTrimActive)   overrideMult = InpPostTrimLotMultiplier;

   double lot = CalculateDCALot(lotIndex, overrideMult, prevLot);

   if(InpUseSLRecovery && seq.recoveryCycle > 0)
      lot = NormalizeLotValue(lot * MathPow(InpSLRecoveryLotMultiplier, seq.recoveryCycle));

   if(InpEnableLotteryMode && seq.lotteryStage > 0 && InpLotterySLMultiplier > 0.0)
      lot = NormalizeLotValue(lot * MathPow(InpLotterySLMultiplier, seq.lotteryStage));

   // --- Che do Xo So: tang khoi luong lenh MOI len theo InpLotteryLotMultiplier de
   //     rut ngan thoi gian dat Target (danh doi rui ro cao hon - xem CheckLotteryTarget()).
   if(InpEnableLotteryMode && InpLotteryLotMultiplier > 0.0)
      lot = NormalizeLotValue(lot * InpLotteryLotMultiplier);

   return(lot);
  }

// Xu ly mo CHUOI LENH MOI (lenh dau tien) cho ca Buy va Sell, tuan thu
// InpTradeExecution, InpAllowNewSequence, Time Filter va Martingale SL Recovery.
void ProcessEntryLogic(const bool canOpenNewSequence)
  {
   if(!canOpenNewSequence) return;

   // --- KHONG mo CHUOI MOI o 1 ben khi ben KIA VAN CON ACTIVE (InpBlockNewSideWhileOtherActive,
   //     mac dinh BAT, ap dung BAT KE ben kia dang am/hoa von/duong, va BAT KE Trend Switch dang
   //     Bat/Tat). Ly do: (1) mo them 1 chuoi doc lap MOI ngay luc tai khoan dang co 1 ben chua
   //     dong xong la them rui ro moi, thay vi tap trung theo doi/xu ly ben con lai cho het; (2)
   //     QUAN TRONG HON, Trend Switch (Section 9.2c) CHI co the kich hoat khi DUNG 1 chuoi dang
   //     active - neu ben kia tu y mo 1 chuoi MOI truoc khi Trend Switch kip xet nguong, dieu kien
   //     "1 chuoi active" bi pha vo NGAY LAP TUC va Trend Switch mat kha nang can thiep cho ca chu
   //     ky nay (cho toi khi 1 trong 2 chuoi dong lai). Ap dung o day - ProcessEntryLogic - la dung
   //     cho: day la duong "mo chuoi TU NHIEN" theo tin hieu/bo loc thong thuong; KHONG anh huong
   //     ManageTrendSwitch() tu mo chuoi "duoi xu huong" cua chinh no (Trend Switch can duoc phep
   //     mo chuoi doi dien CHINH XAC trong tinh huong nay, do la muc dich cua no - day la NGOAI LE
   //     duy nhat, khong bi chan boi dieu kien nay).
   bool buyBlockedByOtherActive  = (InpBlockNewSideWhileOtherActive && g_sellSeq.active);
   bool sellBlockedByOtherActive = (InpBlockNewSideWhileOtherActive && g_buySeq.active);

   if(InpTradeExecution == Buy_Or_Sell)
     {
      if(g_buySeq.active || g_sellSeq.active) return; // Da co 1 chuoi dang chay -> khong mo them chieu kia

      if(!g_manualStopBuy && CanStartNewSequenceNow(1) && IsSignalConfirmed(InpEntrySignal, 1))
        {
         OpenNewOrder(1, ResolveOrderLot(1, g_buySeq));
         return;
        }
      if(!g_manualStopSell && CanStartNewSequenceNow(-1) && IsSignalConfirmed(InpEntrySignal, -1))
        {
         OpenNewOrder(-1, ResolveOrderLot(-1, g_sellSeq));
        }
      return;
     }

   bool allowBuy  = (InpTradeExecution == Buy_And_Sell || InpTradeExecution == Buy_Only) && !g_manualStopBuy && !buyBlockedByOtherActive;
   bool allowSell = (InpTradeExecution == Buy_And_Sell || InpTradeExecution == Sell_Only) && !g_manualStopSell && !sellBlockedByOtherActive;

   if(allowBuy && !g_buySeq.active && CanStartNewSequenceNow(1) && IsSignalConfirmed(InpEntrySignal, 1))
      OpenNewOrder(1, ResolveOrderLot(1, g_buySeq));

   if(allowSell && !g_sellSeq.active && CanStartNewSequenceNow(-1) && IsSignalConfirmed(InpEntrySignal, -1))
      OpenNewOrder(-1, ResolveOrderLot(-1, g_sellSeq));
  }

// Xu ly nhoi them lenh (DCA) cho ca 2 chuoi dang hoat dong, dua tren ShouldOpenDCA() (Section 9.3).
void ProcessDCALogic(const bool canContinueDCA)
  {
   // --- DEBUG TAM THOI (an toan de xoa, cung nhom voi PrintEntryDiagnostics() o Section
   //     13b): moi khi sang 1 nen MOI tren PERIOD_CURRENT, neu 1 chuoi dang active/khong
   //     bi Trend Switch dong bang nhung VAN CHUA duoc DCA them lenh, in ra ly do CU THE
   //     (lay tu outReason cua ShouldOpenDCA()) - giup xac dinh dung ngay dang bi chan boi
   //     dieu kien nao (het Delay, chua du Pips, ADX/ATR filter, Tin hieu DCA, v.v.) thay
   //     vi phai doan. Neu !canContinueDCA (het Session/Daily Block ma InpAllowDCAOutsideSession=false)
   //     cung in ro luon, roi return giong hanh vi cu.
   datetime curBarTimeDCA = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool     isNewDCADebugBar = (curBarTimeDCA != 0 && curBarTimeDCA != g_debugLastDCABarTime);

   if(!canContinueDCA)
     {
      if(isNewDCADebugBar && (g_buySeq.active || g_sellSeq.active))
        {
         g_debugLastDCABarTime = curBarTimeDCA;
         PrintFormat("[DEBUG-DCA] Ca 2 chieu dang bi CHAN DCA boi canContinueDCA=false (Ngoai Session VA InpAllowDCAOutsideSession=false, HOAC da dat Daily Target/Loss va InpStopTradingOnDailyTarget=true).");
        }
      return;
     }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // --- Trend Switch (Section 9.2c) dang kich hoat hay khong, va chieu nao dang bi
   //     "dong bang" (khong nhoi them) / dang "duoi xu huong" (nhoi THUAN, kieu Pyramiding).
   bool buyFrozenBySwitch  = (InpUseTrendSwitch && g_trendSwitchState == -1);
   bool sellFrozenBySwitch = (InpUseTrendSwitch && g_trendSwitchState ==  1);
   bool buyIsChasing       = (InpUseTrendSwitch && g_trendSwitchState ==  1);
   bool sellIsChasing      = (InpUseTrendSwitch && g_trendSwitchState == -1);

   if(isNewDCADebugBar) g_debugLastDCABarTime = curBarTimeDCA;

   if(!g_manualStopBuy && g_buySeq.active && !buyFrozenBySwitch)
     {
      if(buyIsChasing)
        {
         if(ShouldOpenTrendSwitchPyramid(g_buySeq, 1, bid))
            OpenNewOrder(1, ResolveTrendSwitchPyramidLot(1, g_buySeq), true);
        }
      else
        {
         string buyDCAReason = "";
         if(ShouldOpenDCA(g_buySeq, 1, bid, buyDCAReason))
            OpenNewOrder(1, ResolveOrderLot(1, g_buySeq), true);
         else if(isNewDCADebugBar)
            PrintFormat("[DEBUG-DCA] BUY (Lenh:%d) CHUA duoc nhoi them - Ly do: %s", g_buySeq.totalOrders, buyDCAReason);
        }
     }
   else if(isNewDCADebugBar && g_buySeq.active && buyFrozenBySwitch)
      PrintFormat("[DEBUG-DCA] BUY (Lenh:%d) dang bi Trend Switch DONG BANG (khong nhoi DCA thuong, cho Sell duoi xu huong).", g_buySeq.totalOrders);

   if(!g_manualStopSell && g_sellSeq.active && !sellFrozenBySwitch)
     {
      if(sellIsChasing)
        {
         if(ShouldOpenTrendSwitchPyramid(g_sellSeq, -1, ask))
            OpenNewOrder(-1, ResolveTrendSwitchPyramidLot(-1, g_sellSeq), true);
        }
      else
        {
         string sellDCAReason = "";
         if(ShouldOpenDCA(g_sellSeq, -1, ask, sellDCAReason))
            OpenNewOrder(-1, ResolveOrderLot(-1, g_sellSeq), true);
         else if(isNewDCADebugBar)
            PrintFormat("[DEBUG-DCA] SELL (Lenh:%d) CHUA duoc nhoi them - Ly do: %s", g_sellSeq.totalOrders, sellDCAReason);
        }
     }
   else if(isNewDCADebugBar && g_sellSeq.active && sellFrozenBySwitch)
      PrintFormat("[DEBUG-DCA] SELL (Lenh:%d) dang bi Trend Switch DONG BANG (khong nhoi DCA thuong, cho Buy duoi xu huong).", g_sellSeq.totalOrders);
  }

//======================================================================
// 13b. DEBUG TAM THOI - In 1 dong chan doan MOI KHI CO NEN MOI tren
//      InpSignalTimeframe, liet ke DONG THOI toan bo dieu kien Entry (tin
//      hieu, spread, session, quyen AutoTrading...) de xac dinh chinh xac
//      dang bi chan o buoc nao (hoac xac nhan OnTick co thuc su chay hay
//      khong). AN TOAN DE XOA: co the xoa toan bo ham nay + dong goi no
//      trong OnTick() + khai bao g_debugLastBarTime o Section 4.6b, EA se
//      tro lai y het ban goc, khong anh huong logic giao dich that.
//======================================================================
// DEBUG-ONLY: tinh lai HUONG SUPERTREND HIEN TAI (khong gioi han "chi bao khi vua flip"
// nhu BiasFromSupertrend() that su dung trong giao dich) - chi de HIEN THI cho nguoi dung
// thay huong trend dang la gi ngay luc nay, phan biet "dang giu nguyen 1 huong lau roi,
// chua flip" voi "co van de tinh toan". Khong anh huong logic vao lenh that.
int DebugCurrentSupertrendTrend()
  {
   if(h_ATR_Supertrend == INVALID_HANDLE) return(0);
   int n = 100;
   double h2[], l2[], c2[], a2[];
   if(!FetchChronoOHLC(InpSignalTimeframe, n, 1, h2, l2, c2)) return(0);
   if(!FetchChronoBuffer(h_ATR_Supertrend, 0, n, 1, a2))      return(0);

   double upBand[], dnBand[];
   int    trendArr[];
   ArrayResize(upBand, n); ArrayResize(dnBand, n); ArrayResize(trendArr, n);

   for(int i = 0; i < n; i++)
     {
      double mid     = (h2[i] + l2[i]) / 2.0;
      double basicUp = mid + InpSupertrend_Multiplier * a2[i];
      double basicDn = mid - InpSupertrend_Multiplier * a2[i];

      if(i == 0) { upBand[i] = basicUp; dnBand[i] = basicDn; trendArr[i] = 1; continue; }

      upBand[i] = (basicUp < upBand[i-1] || c2[i-1] > upBand[i-1]) ? basicUp : upBand[i-1];
      dnBand[i] = (basicDn > dnBand[i-1] || c2[i-1] < dnBand[i-1]) ? basicDn : dnBand[i-1];

      if(trendArr[i-1] == 1) trendArr[i] = (c2[i] < dnBand[i]) ? -1 : 1;
      else                   trendArr[i] = (c2[i] > upBand[i]) ? 1 : -1;
     }
   return(trendArr[n-1]);
  }

void PrintEntryDiagnostics()
  {
   datetime curBarTime = iTime(_Symbol, InpSignalTimeframe, 0);
   if(curBarTime == 0 || curBarTime == g_debugLastBarTime) return;
   g_debugLastBarTime = curBarTime;

   double spreadPips = PriceToPips(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   int    curTrendNow = (InpEntrySignal == Supertrend) ? DebugCurrentSupertrendTrend() : 0;

   // --- Cong thuc DUNG 100% giong het canOpenNewSequence trong OnTick() (Section 14) - in
   //     rieng tung thanh phan de biet CHINH XAC thanh phan nao dang chan (thay vi 1 co
   //     "SessionOk" gop chung de rat de hieu lam - truoc day chi in IsWithinTradingSession(),
   //     THIEU ca Weekday va News, khong khop 100% voi cong thuc that su dung de mo lenh).
   bool dbgTimeFilterOk = IsWithinTradingSession();
   bool dbgWeekdayOk    = IsWeekdayTradingAllowed();
   bool dbgNewsOk       = !IsHighImpactNewsWindow();
   bool dbgSessionOk    = dbgTimeFilterOk && dbgWeekdayOk && dbgNewsOk;
   bool dbgDailyBlocked = (InpUseDailyTarget && InpStopTradingOnDailyTarget && IsDailyTargetReached());
   bool dbgCanOpenNew   = InpAllowNewSequence && dbgSessionOk && !dbgDailyBlocked;

   // --- Chia thanh 3 dong NGAN (thay vi 1 dong rat dai de dam bao KHONG bi cua so Nhat Ky
   //     cat mat chu, dac biet la cac co CHAN LENH quan trong nhat luon dat DAU MOI dong).
   PrintFormat("[DEBUG-1/3] Nen moi %s | RawBias(%s)=%d | XacNhanBUY=%s | XacNhanSELL=%s | Trend=%s",
               TimeToString(curBarTime, TIME_DATE | TIME_MINUTES),
               EnumToString(InpEntrySignal), GetRawBias(InpEntrySignal),
               (IsSignalConfirmed(InpEntrySignal, 1)  ? "true" : "false"),
               (IsSignalConfirmed(InpEntrySignal, -1) ? "true" : "false"),
               (InpEntrySignal == Supertrend ? (curTrendNow == 1 ? "TANG" : (curTrendNow == -1 ? "GIAM" : "N/A")) : "N/A"));

   PrintFormat("[DEBUG-2/3] CHO PHEP MO CHUOI MOI = %s | AllowNewSeq=%s SessionOk=%s(TimeFilter=%s Weekday=%s News=%s) DailyBlocked=%s",
               (dbgCanOpenNew ? "CO" : "KHONG"),
               (InpAllowNewSequence ? "true" : "false"),
               (dbgSessionOk ? "true" : "false"), (dbgTimeFilterOk ? "true" : "false"),
               (dbgWeekdayOk ? "true" : "false"), (dbgNewsOk ? "true" : "false"),
               (dbgDailyBlocked ? "true" : "false"));

   PrintFormat("[DEBUG-3/3] CanStartBuy=%s CanStartSell=%s | Spread=%.1f/Max=%.1f | BuySeq.active=%s SellSeq.active=%s | AutoTrading[MQL/Terminal]=%s/%s",
               (CanStartNewSequenceNow(1)  ? "true" : "false"),
               (CanStartNewSequenceNow(-1) ? "true" : "false"),
               spreadPips, InpMaxSpreadPips,
               (g_buySeq.active ? "true" : "false"), (g_sellSeq.active ? "true" : "false"),
               (MQLInfoInteger(MQL_TRADE_ALLOWED) ? "true" : "false"),
               (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "true" : "false"));
  }

//======================================================================
// 14. LUONG XU LY CHINH (MAIN ORCHESTRATION) - OnTick() / OnTimer()
//======================================================================
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   PrintEntryDiagnostics(); // <-- DEBUG TAM THOI, xem ghi chu Section 13b o tren.

// --- 14.0 Che do Xo So: kiem tra Target truoc tien - neu da dat, EA se tu dong
//          dong het lenh va NGAT (ExpertRemove) ngay trong ham nay, khong xu ly gi them.
   CheckLotteryTarget();

   CheckDailyReset();

// --- 14.1 Dong bo trang thai tu Position that (nguon du lieu duy nhat)
   SyncSequenceFromPositions();
   UpdateMaxDrawdownTracking();

   // UPGRADE v3.0.6: Lich theo ngay trong tuan + Bo loc Tin tuc ap dung CHUNG cho ca
   // Entry (chuoi moi) va DCA o day - rieng DCA con duoc kiem tra THEM 1 lan nua ben
   // trong ShouldOpenDCA_Core() (Section 9.2b) de an toan ke ca khi goi truc tiep.
   bool sessionOk        = IsWithinTradingSession() && IsWeekdayTradingAllowed() && !IsHighImpactNewsWindow();
   bool dailyBlocked     = InpUseDailyTarget && InpStopTradingOnDailyTarget && IsDailyTargetReached();
   bool canOpenNewSequence = InpAllowNewSequence && sessionOk && !dailyBlocked;
   bool canContinueDCA     = (sessionOk || InpAllowDCAOutsideSession) && !dailyBlocked;

// --- 14.2 Risk Engine: SL Recovery -> Target Profit/Risk -> Step Profit Lock ->
//          Trailing Stop -> Hedging Zone -> Partial Closure (TAM DUNG neu dang Hedge)
   ProcessSLRecovery(g_buySeq, 1);
   ProcessSLRecovery(g_sellSeq, -1);

   EvaluateAccountTargets();

   // --- Trend Switch (Section 9.2c) dang "duoi xu huong" ben nao thi TAM MIEN TRU ben do
   //     khoi Money TP thuong (InpUseBuyTP/InpUseSellTP, VD $50 chot ca chuoi) - neu khong,
   //     chuoi dang "duoi" se bi chot cung nguong $ NHU 1 chuoi binh thuong, cat ngang mat
   //     y nghia "giu nguyen lai, cho tin hieu dao chieu/ADX yeu" cua Trend Switch. SL van
   //     ap dung binh thuong (khong mien tru) vi day la lop bao ve rui ro, khong phai chot loi.
   bool buyChasingBySwitch  = (InpUseTrendSwitch && g_trendSwitchState ==  1);
   bool sellChasingBySwitch = (InpUseTrendSwitch && g_trendSwitchState == -1);
   EvaluateSideTargets(g_buySeq, 1, (InpUseBuyTP && !buyChasingBySwitch), InpBuyTP_IsPercent, InpBuyTP_Value, InpUseBuySL, InpBuySL_IsPercent, InpBuySL_Value);
   EvaluateSideTargets(g_sellSeq, -1, (InpUseSellTP && !sellChasingBySwitch), InpSellTP_IsPercent, InpSellTP_Value, InpUseSellSL, InpSellSL_IsPercent, InpSellSL_Value);
   EvaluateStepProfitLock(g_buySeq, 1);
   EvaluateStepProfitLock(g_sellSeq, -1);

   ManageTrailingStop(g_buySeq, 1);
   ManageTrailingStop(g_sellSeq, -1);

   EvaluateEmergencyTP(g_buySeq, 1);
   EvaluateEmergencyTP(g_sellSeq, -1);

   EvaluateChainTP(g_buySeq, 1);
   EvaluateChainTP(g_sellSeq, -1);

   CheckMaxLotNewCycle(g_buySeq, 1);
   CheckMaxLotNewCycle(g_sellSeq, -1);

   if(InpEnableLotteryMode)
     {
      CheckLotteryCutLoss(g_buySeq, 1);
      CheckLotteryCutLoss(g_sellSeq, -1);
     }

   CheckHedgeZoneTrigger();
   CheckHedgingZoneTrigger();
   ManageOppositeOrder(1);
   ManageOppositeOrder(-1);

// Tia lenh (Partial Closure + Advanced Trim + Cross-Sequence Trim) mac dinh chi
// chay khi KHONG co lenh Hedge dang mo - trong luc dang Hedge, viec cat bot lenh
// se lam sai lech ty le bao ve cua vung Hedge. Bat InpHedgeStopTrimWhileActive=false
// de van cho phep Tia lenh chay ngay ca khi dang co lenh Hedge.
   if(!g_hedge.active || !InpHedgeStopTrimWhileActive)
     {
      if(CheckPartialCloseCondition(g_buySeq))  ExecutePartialClosure(g_buySeq, tick.bid);
      if(CheckPartialCloseCondition(g_sellSeq)) ExecutePartialClosure(g_sellSeq, tick.ask);

      ProcessAdvancedTrim(g_buySeq, 1, tick.bid);
      ProcessAdvancedTrim(g_sellSeq, -1, tick.ask);
      ProcessPartialTrim(g_buySeq, 1, tick.bid);
      ProcessPartialTrim(g_sellSeq, -1, tick.ask);
      EvaluatePostTrimTP(g_buySeq, 1);
      EvaluatePostTrimTP(g_sellSeq, -1);

      ProcessCrossSequenceTrim();
     }

// Lot Equalizer chay doc lap voi trang thai Hedge (chi can bang khoi luong
// giua 2 chuoi Buy/Sell thong thuong, khong lien quan lenh Hedge/Equalizer).
   CheckLotEqualizer();

// --- 14.3 Dong bo lai truoc khi xet Entry/DCA (phan anh dung cac hanh dong dong lenh o tren)
   SyncSequenceFromPositions();

// Dong lenh khi tin hieu dao chieu (neu bat) - phai chay TRUOC Entry Logic de
// "nhuong cho" ngay chuoi moi mo cung 1 tick khi tin hieu vua doi chieu.
   CheckTrendReversalClose();

// Trend Switch (Section 9.2c) - phai chay TRUOC Entry/DCA Logic de kip mo/danh dau
// chieu "duoi xu huong" hoac chot chieu do NGAY trong cung 1 tick tin hieu dao chieu.
   ManageTrendSwitch(canOpenNewSequence);

// --- 14.4 Grid/DCA Orchestration: mo chuoi moi (Entry) va nhoi lenh (DCA)
   ProcessEntryLogic(canOpenNewSequence);
   ProcessDCALogic(canContinueDCA);
  }

void OnTimer()
  {
   CheckDailyReset();
   SyncSequenceFromPositions();

   ManageVirtualTPSL();
   ManageHedgePosition();
   ManageHedgingZone();
   CheckStaircaseTarget();

   UpdateDashboard();
  }

//======================================================================
// 15. XU LY SU KIEN CHART (ONCHARTEVENT) - Bat click 5 nut HUD tuong tac
//     (Close Buy/Sell, Reset Lots, Stop Buy/Sell) duoc ve trong Section 12.1.
//======================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == HUD_PREFIX + "BTN_CLOSEBUY")
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // Nut "momentary" - tu bat len ngay sau khi bam
      if(g_buySeq.active)
        {
         PrintFormat("[Huuoaifx DCA] HUD Button [Close Buy]: dong toan bo chuoi BUY theo yeu cau thu cong.");
         CloseAllOrdersInSequence(g_buySeq);
         g_buySeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
        }
      UpdateDashboard();
      return;
     }

   if(sparam == HUD_PREFIX + "BTN_CLOSESELL")
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      if(g_sellSeq.active)
        {
         PrintFormat("[Huuoaifx DCA] HUD Button [Close Sell]: dong toan bo chuoi SELL theo yeu cau thu cong.");
         CloseAllOrdersInSequence(g_sellSeq);
         g_sellSeq.recoveryCycle = 0;
         SyncSequenceFromPositions();
        }
      UpdateDashboard();
      return;
     }

   if(sparam == HUD_PREFIX + "BTN_RESETLOTS")
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      g_forceInitialLotBuy  = true;
      g_forceInitialLotSell = true;
      PrintFormat("[Huuoaifx DCA] HUD Button [Reset Lots]: Lenh Entry/DCA TIEP THEO (ca Buy va Sell) se dung dung InpInitialLot.");
      UpdateDashboard();
      return;
     }

   if(sparam == HUD_PREFIX + "BTN_STOPBUY")
     {
      g_manualStopBuy = !g_manualStopBuy;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // Trang thai ON/OFF hien thi qua mau/text nut, khong dung STATE bam giu
      PrintFormat("[Huuoaifx DCA] HUD Button [Stop Buy] = %s.", (g_manualStopBuy ? "ON (tam dung mo lenh Buy moi)" : "OFF"));
      UpdateDashboard();
      return;
     }

   if(sparam == HUD_PREFIX + "BTN_STOPSELL")
     {
      g_manualStopSell = !g_manualStopSell;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      PrintFormat("[Huuoaifx DCA] HUD Button [Stop Sell] = %s.", (g_manualStopSell ? "ON (tam dung mo lenh Sell moi)" : "OFF"));
      UpdateDashboard();
      return;
     }
  }
//+------------------------------------------------------------------+
