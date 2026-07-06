import '../models/transaction_model.dart';

/// Service for parsing bank SMS messages to extract transaction details
class SmsParserService {
  // Common Indian bank sender patterns
  static final List<String> _bankSenderPatterns = [
    // --- Your Original List ---
    'SBIINB',
    'SBIUPI',
    'SBIBNK',
    'SBIPSG',
    'ATMSBI',
    'CSBSBI',
    'SBIATM',
    'SBISMS',
    'IDBIBK',
    'INDUSN',
    'HDFCBK',
    'ICICIB',
    'ICICIT',
    'AXISBK',
    'KOTAKB',
    'PNBSMS',
    'BOIIND',
    'BOISMS',
    'CANBNK',
    'UNIONB',
    'IABORB',
    'YESBAK',
    'INDUSB',
    'FEDERA',
    'IDFCFB',
    'RBLBNK',
    'PAYTMB',
    'GPAY',
    'PHONEPE',
    'PAYTM',
    'AMAZONP',
    'APAY',
    'MAHABNK',
    'MAHABK',
    'BOMSMS',
    'CENTBK',
    'SCBSMS',
    'CITIBNK',
    'DBISHR',
    // NOTE: entries must be uppercase — they are matched against an
    // uppercased sender in isBankSms().
    'SIMPLPL',
    'BANK OF BARODA',
    'BANK OF MAHARASHTRA',
    'IDBI BANK LIMITED',
    'BANK OF INDIA',

    // --- Newly Appended Extensions ---
    'SBIFMS',
    'SBIYONO',
    'JOSBII',
    'SBILDG',
    'HDFCCN',
    'HDFCAL',
    'HDFCTX',
    'HDFCBF',
    'ICICIP',
    'ICICIC',
    'ICICIA',
    'AXISBNK',
    'AXISBI',
    'AXCHG',
    'BARODA',
    'BOBTXN',
    'BOBSMS',
    'BOBBNK',
    'PNBINF',
    'PNBBNK',
    'PNBPRD',
    'IDBIBK',
    'IDBIMS',
    'IDBIEX',
    'IOBAST',
    'IOBANK',
    'INDYAL',
    'IDNBNK',
    'CBIINB',
    'UCOBNK',
    'UCOFTN',
    'CNRBNK',
    'CANARA',
    'UBIINB',
    'UBISMS',
    'INDUSI',
    'BANDHN',
    'BNDHNB',
    'BDHNBK',
    'SIBLTD',
    'SIBPLZ',
    'KVBLTD',
    'KVBBNK',
    'FEDBNK',
    'RBLSMS',
    'RBLCC',
    'JKBNK',
    'JKBANK',
    'AIRTELP',
    'ATLPAY',
    'FINOPB',
    'FINOBK',
    'JIOSMS',
    'JIOBPY',
    'IPPBANK',
    'IPPSMS',
    'MOBIKW',
    'KWIK24',
    'FREECH',
    'DREAMP',
    'BAJAJF',
    'BJFLTX',
    'DBSBNK',
    'CITIBK',
    'HSBCBK',
    'HSBNK',
    'SCBLTD',
    'AMEXBK',
    // --- Additional Banks / Neo Banks ---
    'SARBNK',
    'SBIYONO',
    'MAHAMB',
    'JUPITR',
    'FIMONY',
    'NIYOGB',
    'AUBNK',
    'AUSFB',
    'EQUIBNK',
    'ESFB',
    'UJJIVN',
    'SARASW',
    'KVBSMS',
    'SIBBNK',
    'CUBANK',
    'CUBSMS',
    'KBLBNK',
    'KBLSMS',
    'DHANBK',
    'TMBSMS',
    // --- Extended Bank Sender Codes from list_of_banks.txt (1482 entries) ---
    '100022',
    '100026',
    '100075',
    '100811',
    '101979',
    '106486',
    '107001',
    '107750',
    '110111',
    '111000',
    '111014',
    '111101',
    '111102',
    '111103',
    '111104',
    '111105',
    '111106',
    '111107',
    '111108',
    '111109',
    '111444',
    '111540',
    '111555',
    '111611',
    '111666',
    '111888',
    '111904',
    '111917',
    '111921',
    '111979',
    '112000',
    '113000',
    '113311',
    '114411',
    '115551',
    '115651',
    '116001',
    '116077',
    '116611',
    '118467',
    '119351',
    '120011',
    '120012',
    '120017',
    '121111',
    '121200',
    '121314',
    '121906',
    '122333',
    '123323',
    '123409',
    '126000',
    '126001',
    '126002',
    '126003',
    '126666',
    '126995',
    '127777',
    '128119',
    '130000',
    '130001',
    '130011',
    '130012',
    '130013',
    '131415',
    '132132',
    '133333',
    '140001',
    '140011',
    '140285',
    '140601',
    '141516',
    '142019',
    '142421',
    '142424',
    '143242',
    '144806',
    '146587',
    '150000',
    '150001',
    '150773',
    '151053',
    '151234',
    '151892',
    '151899',
    '151974',
    '152484',
    '154321',
    '154987',
    '155551',
    '158412',
    '159159',
    '160001',
    '171717',
    '172586',
    '177177',
    '180012',
    '180224',
    '180597',
    '180797',
    '180897',
    '181200',
    '181212',
    '181818',
    '181964',
    '184001',
    '185241',
    '188888',
    '189766',
    '190000',
    '191600',
    '191607',
    '192518',
    '199199',
    '199802',
    '20001',
    '650017',
    '650137',
    'ACBLBK',
    'ACBLHO',
    'ACCBNK',
    'ACEPLC',
    'ADARSH',
    'ADBCCB',
    'ADHBNK',
    'ADINBK',
    'ADRBNK',
    'AEITSM',
    'AGMITS',
    'AGRABK',
    'AGVBNK',
    'AGVCBS',
    'AIRBNK',
    'AIRBSE',
    'AIRBSI',
    'AJUSBJ',
    'AKHAND',
    'AKOLAB',
    'ALBANK',
    'ALMABK',
    'ALMORA',
    'ALVIBK',
    'ALYBNK',
    'AMBUJA',
    'AMCBNK',
    'AMCOBK',
    'AMEXBP',
    'AMEXBT',
    'AMEXEP',
    'AMEXIN',
    'AMEXSR',
    'ANDBNK',
    'ANSBNK',
    'APCBNK',
    'APGBBK',
    'APGBHO',
    'APGBIT',
    'APGBNK',
    'APGECM',
    'APGVBK',
    'APHOAT',
    'APNABK',
    'APNAPR',
    'APNATR',
    'APRBBK',
    'APRBHO',
    'APSCOB',
    'APSSBN',
    'APXBNK',
    'ASBALT',
    'ASBANK',
    'ASCBNK',
    'ASSBNK',
    'ASSOBK',
    'ATMMON',
    'ATMMVS',
    'ATMSMS',
    'ATMTAD',
    'ATPCCB',
    'AUBANK',
    'AUBMSG',
    'AUBSMS',
    'AUCBNK',
    'AUDOST',
    'AUITSM',
    'AXISB',
    'AXISHR',
    'AXISIN',
    'AXISMR',
    'AXISPR',
    'AXISSR',
    'AXPOPS',
    'AXPVPN',
    'AXSFI',
    'AXSFIN',
    'AZPSSB',
    'BANKIT',
    'BASAVA',
    'BASBNK',
    'BASODA',
    'BCCBBK',
    'BCOBBK',
    'BCRBNK',
    'BCUBNK',
    'BDCCBK',
    'BDNSMS',
    'BEGUBK',
    'BETDBK',
    'BGVBNK',
    'BGVCBS',
    'BHABHR',
    'BHAGNI',
    'BHGINI',
    'BHRDBK',
    'BHUBNK',
    'BHUJBK',
    'BKDENA',
    'BKPNSB',
    'BMCBBK',
    'BMCBNK',
    'BMSHAB',
    'BMSNAN',
    'BNDNBK',
    'BNDNHL',
    'BNKBCB',
    'BNSBKL',
    'BNSBL',
    'BNSBNK',
    'BOBBIZ',
    'BOBCMS',
    'BOBCRM',
    'BOBFRM',
    'BOBMSG',
    'BOBOTP',
    'BOBRAJ',
    'BOBSCE',
    'BOBSCF',
    'BOBTRE',
    'BOBUPG',
    'BOBUPI',
    'BOIBAL',
    'BOIINT',
    'BOIJGB',
    'BOILON',
    'BOINJG',
    'BOIREM',
    'BOISAF',
    'BOISME',
    'BOIVKG',
    'BOMSCT',
    'BPMCTR',
    'BRAMHA',
    'BRDSEC',
    'BRIMPS',
    'BRKGBD',
    'BRKGBM',
    'BRKGBS',
    'BRKGBX',
    'BSBBMT',
    'BSBLBK',
    'BSBLTD',
    'BSCBNK',
    'BUCBBK',
    'BUCBKL',
    'BUCBLB',
    'BUCBNK',
    'BUCBRJ',
    'BULAND',
    'BUPGBB',
    'BUPGBM',
    'BUPGBX',
    'BURBAN',
    'BWRUCB',
    'BZRCMB',
    'CAANBK',
    'CANMNY',
    'CANRRB',
    'CANRWD',
    'CBGUNA',
    'CBIOTP',
    'CBREWA',
    'CBSKUB',
    'CBSLTD',
    'CBSSBI',
    'CBSTGB',
    'CCBANK',
    'CCBBTL',
    'CCBCHW',
    'CCBDTA',
    'CCBDWS',
    'CCBFAZ',
    'CCBGUR',
    'CCBGWL',
    'CCBJBK',
    'CCBJMU',
    'CCBKGN',
    'CCBKNW',
    'CCBLTD',
    'CCBMOR',
    'CCBRJG',
    'CCBROP',
    'CCBSAS',
    'CCBSDH',
    'CCBSGR',
    'CCBSHR',
    'CCBSNI',
    'CCBSTN',
    'CCBSVP',
    'CCBTKG',
    'CCCDEL',
    'CCHRIR',
    'CCOBNK',
    'CCONLN',
    'CCPCAH',
    'CCPCCN',
    'CCRSBI',
    'CDSAFE',
    'CFOBAN',
    'CGAPBK',
    'CGBBBK',
    'CGGBNK',
    'CHADCC',
    'CHAMBK',
    'CHAMCO',
    'CHDSBK',
    'CHHIBK',
    'CHOINS',
    'CHSBNK',
    'CHSCBK',
    'CHVRBK',
    'CIRALT',
    'CITI',
    'CITIBA',
    'CITIBN',
    'CITYBK',
    'CLABBK',
    'CMPHYD',
    'CMSRBI',
    'CNBANK',
    'CNSBLH',
    'CNSBNK',
    'COCBNG',
    'COMCBL',
    'CORPBK',
    'COSTAL',
    'COVIGL',
    'CPCBBK',
    'CRGBAD',
    'CSBANK',
    'CSBBNK',
    'CSBN',
    'CSBNKN',
    'CSCBNK',
    'CSDSBI',
    'CSFBNK',
    'CTDSBI',
    'CTMUGM',
    'CTRCCB',
    'CTZENS',
    'CUBFST',
    'CUBLTD',
    'CUBOTP',
    'CUBUPI',
    'CUCBNK',
    'CVELUC',
    'DACBNK',
    'DAHODB',
    'DBALRT',
    'DBKTNM',
    'DBPSBI',
    'DCBANK',
    'DCBBNK',
    'DCBDCB',
    'DCBGZB',
    'DCBMBD',
    'DCBMDL',
    'DCBMRT',
    'DCCBKC',
    'DCCBLK',
    'DCCBLN',
    'DCGBBK',
    'DDCCBK',
    'DEEBNK',
    'DEENBK',
    'DENABK',
    'DEOBNK',
    'DEUTBK',
    'DGBSMS',
    'DGGBNK',
    'DGLCBK',
    'DGMGZB',
    'DGMGZD',
    'DGMRBD',
    'DGTBNK',
    'DHARBK',
    'DHARCB',
    'DHARMA',
    'DHRTBK',
    'DITATM',
    'DITHLP',
    'DMCBKL',
    'DMCBNK',
    'DMCDHD',
    'DMNSBK',
    'DMSALT',
    'DNSBNK',
    'DOHABK',
    'DOMBNK',
    'DPCSDX',
    'DSBANK',
    'DSUCBK',
    'DUBANK',
    'DUCBDA',
    'DUCOBK',
    'DUNDCB',
    'DUNICA',
    'DURGBK',
    'EASFBT',
    'EBTALT',
    'ECOMPW',
    'EDBANK',
    'EDSADM',
    'EMLOTP',
    'EQBANK',
    'EQUTAS',
    'EQUTAT',
    'EQUTAX',
    'ESAFIT',
    'ESAFOT',
    'ESAFPB',
    'ESAFPR',
    'ESAFSF',
    'ESAFTR',
    'ESFUAT',
    'EXCLCK',
    'EXIMBK',
    'FASTDV',
    'FCHRGE',
    'FDBOTP',
    'FEDADV',
    'FEDFIN',
    'FEDOTP',
    'FGMCHN',
    'FGMMUM',
    'FGUCBK',
    'FIDSBI',
    'FINOHR',
    'FINOIN',
    'FMCLUC',
    'FNCARE',
    'FNGWBK',
    'FROMSC',
    'FSLOCT',
    'FZKCCB',
    'GARHBK',
    'GBCBBK',
    'GBCBBN',
    'GCBBNK',
    'GCCSBI',
    'GDVBNK',
    'GMCCDC',
    'GMPERS',
    'GMSMAD',
    'GNDDCC',
    'GNSBKL',
    'GNSBLT',
    'GPPJSB',
    'GPPSBL',
    'GRAMEN',
    'GRBANK',
    'GRCSBG',
    'GRCSBI',
    'GSBANK',
    'GSCBBK',
    'GSCBNK',
    'GSCLOC',
    'GSSBNK',
    'GTRCCB',
    'GUBANK',
    'GUBNKO',
    'GUCBNK',
    'GUCBSI',
    'GUCBSR',
    'GUCBTR',
    'GUJAMB',
    'GVNSBL',
    'HARCOB',
    'HARDBK',
    'HARIDC',
    'HASTIB',
    'HDCCBK',
    'HDFCBA',
    'HDFCBN',
    'HDFCCC',
    'HDFCDC',
    'HDFCFD',
    'HDFCGC',
    'HDFCHI',
    'HDFCHL',
    'HDFCIT',
    'HDFCLI',
    'HDFCPL',
    'HDFCRD',
    'HDFCSD',
    'HDFCSE',
    'HDFCUN',
    'HDFSET',
    'HDFTST',
    'HMCBNK',
    'HNSBLH',
    'HNSBNK',
    'HOCPPC',
    'HOHRMS',
    'HORRMD',
    'HOSRDD',
    'HPGSMS',
    'HPSBNK',
    'HRHDFC',
    'HRMSCC',
    'HSBANK',
    'HSBCEX',
    'HSBCIM',
    'HSBCIN',
    'HSBLBK',
    'HSBNKW',
    'HUCBNK',
    'HYDCCB',
    'IAPPRV',
    'ICBANK',
    'ICIBNK',
    'ICICBK',
    'ICICIH',
    'ICICIK',
    'ICICIL',
    'ICICTC',
    'ICIEMP',
    'ICIOTP',
    'ICMTRG',
    'IDBIDL',
    'IDFCBK',
    'IDFCCM',
    'IDFCFZ',
    'IDFCIT',
    'IDFCTS',
    'IDFCZ',
    'IDFSIT',
    'IDRNSB',
    'IDRSNB',
    'IMAHYD',
    'IMCOBK',
    'IMSBNK',
    'INBUPI',
    'INDBNK',
    'INDUSA',
    'INDUSO',
    'INTBNK',
    'IOBATM',
    'IOBBNK',
    'IOBBQR',
    'IOBCHN',
    'IOBHRD',
    'IOBJLS',
    'IOBMKT',
    'IOBOTP',
    'IPBCOM',
    'IPBKYC',
    'IPBMSG',
    'IPBOFR',
    'IPBOTP',
    'IPBSEC',
    'IPCBBK',
    'IPCBNK',
    'IPSBNK',
    'IPSHOI',
    'IPSHOT',
    'ISBANK',
    'ISDSBI',
    'ISECLD',
    'ISRVCE',
    'ITCBBK',
    'ITCBNK',
    'ITCOMP',
    'ITRISK',
    'ITRSNC',
    'ITSDEL',
    'ITSLHO',
    'JALAUN',
    'JALORE',
    'JANABK',
    'JANATR',
    'JANATX',
    'JANSVA',
    'JANTHA',
    'JAOLIB',
    'JCBANK',
    'JCCB',
    'JCCBNK',
    'JCOMBK',
    'JGRAMN',
    'JIVAJI',
    'JJSBNK',
    'JKBFSL',
    'JKCARD',
    'JKGRAM',
    'JKGRMN',
    'JKGRNB',
    'JKSBLM',
    'JLRNSB',
    'JMCBNK',
    'JMSBLP',
    'JMSBNK',
    'JNJCBL',
    'JNSBBM',
    'JNSBJU',
    'JNSBKL',
    'JNSEVA',
    'JPCBNK',
    'JPNBNK',
    'JRGBNK',
    'JSBANK',
    'JSBGON',
    'JSBLBK',
    'JSBLHG',
    'JSBLHO',
    'JSBLPN',
    'JSBRYP',
    'JSCBKL',
    'JSKABK',
    'JSKBBG',
    'JSKBBK',
    'JSKBCP',
    'JSKBDA',
    'JSKBHB',
    'JSKBJH',
    'JSKBJP',
    'JSKBMS',
    'JSKBNP',
    'JSKBRS',
    'JSKBRT',
    'JSKBSD',
    'JSKBSJ',
    'JSKBUJ',
    'JSKBVI',
    'JSKJBK',
    'JUCBNK',
    'JUSBNK',
    'KAGBNK',
    'KAIJSB',
    'KARBNK',
    'KBANKT',
    'KBSBBK',
    'KBSBNK',
    'KCBANK',
    'KCCBNK',
    'KCCBPS',
    'KCCDWD',
    'KCDCCB',
    'KCMEET',
    'KCMSGS',
    'KCOBBK',
    'KCRBNK',
    'KCUBNK',
    'KDCBAK',
    'KDCCBK',
    'KDCCBL',
    'KDGCCB',
    'KDPCCB',
    'KEBANK',
    'KGBANK',
    'KHEDAB',
    'KHLADM',
    'KKDCCB',
    'KMBCBL',
    'KMCBK',
    'KMCBLT',
    'KMCBNK',
    'KMNBNK',
    'KNBOTP',
    'KNSBBK',
    'KNSBKL',
    'KNSBKN',
    'KNSBLK',
    'KNSBNK',
    'KOTABK',
    'KOTAKP',
    'KOTSBN',
    'KOYANA',
    'KPCOBL',
    'KPMCCB',
    'KRICCB',
    'KRNBNK',
    'KRNDBK',
    'KRTBNK',
    'KRUSHI',
    'KSBLBK',
    'KTCCBL',
    'KTKBNK',
    'KTKREM',
    'KTWBNK',
    'KUBANK',
    'KUBOTP',
    'KUBPRO',
    'KUBSMS',
    'KUBTRN',
    'KUCBBK',
    'KUCBNK',
    'KUCBOT',
    'KUCBTR',
    'KUNSBB',
    'KUNSUB',
    'KVBANK',
    'KVBOTP',
    'KVBUPI',
    'KVGBBK',
    'KVGBNK',
    'KVGECM',
    'LALABK',
    'LAXBNK',
    'LCTSCS',
    'LDMFBD',
    'LHOABU',
    'LHOBAN',
    'LHOGMI',
    'LHOKOL',
    'LHOPAT',
    'LICCRD',
    'LMPUCB',
    'LNSBNK',
    'LUCBNK',
    'LVBANK',
    'LVBSMS',
    'MABHYD',
    'MAKBNK',
    'MALOJI',
    'MAMCOB',
    'MANSBK',
    'MARSCB',
    'MAYANI',
    'MBIMPS',
    'MBTEST',
    'MCAPEX',
    'MCBANK',
    'MCBATM',
    'MCBBNK',
    'MCBLTD',
    'MCBNSK',
    'MCBOTP',
    'MCBTRN',
    'MCCBNK',
    'MCDCCB',
    'MCNBBK',
    'MCOBNK',
    'MCUBLH',
    'MCUBNK',
    'MDCBKL',
    'MDCBNK',
    'MDKNSB',
    'MDLUCB',
    'MDMSBK',
    'MEGRRB',
    'MFDUBK',
    'MGBBNK',
    'MGBSMS',
    'MGRBBK',
    'MGSBBK',
    'MHAVIR',
    'MHSJPN',
    'MIAMEX',
    'MIECBL',
    'MIMTMX',
    'MISDEP',
    'MLBANK',
    'MLTBNK',
    'MMSBNK',
    'MNBANK',
    'MNSBKL',
    'MNSBNK',
    'MODNAG',
    'MOGBNK',
    'MORADA',
    'MPAPEX',
    'MPAUCB',
    'MPRSBK',
    'MPSCBK',
    'MPSSBK',
    'MPSSBN',
    'MRBANK',
    'MRBBBK',
    'MRBCBS',
    'MSBLPN',
    'MSBLTD',
    'MSCBKN',
    'MSCBNK',
    'MUBANK',
    'MUCATM',
    'MUCBLP',
    'MUCBNK',
    'MUCBNP',
    'MUCCBS',
    'MUCINB',
    'MUCINF',
    'MUCIPO',
    'MUCMBS',
    'MUCOBK',
    'MUCOTP',
    'MUCUPI',
    'MVCBLS',
    'MYAMEX',
    'MYIPPB',
    'MZBANK',
    'MZBBBK',
    'MZSBNK',
    'NABARD',
    'NCBANK',
    'NCBLBK',
    'NDVSBK',
    'NICBNK',
    'NISBNK',
    'NJMSBL',
    'NKDCCB',
    'NKRDBK',
    'NPCMPL',
    'NSBANK',
    'NSBETW',
    'NSBNKN',
    'NSCBAK',
    'NSCBNK',
    'NSDLCD',
    'NSDLPB',
    'NSDLRM',
    'NSTCBL',
    'NTLBNK',
    'NUCBNK',
    'NUCBRM',
    'NUTANB',
    'NVNBNK',
    'NVSHUP',
    'NZBCCB',
    'OBCBNK',
    'OBCCBS',
    'OBCINB',
    'OBCMBK',
    'OBCOLS',
    'OBCOTP',
    'OBCSMS',
    'OBCSVC',
    'OBCTXN',
    'OBCUPI',
    'OCUBNK',
    'OSCBNK',
    'OTPSKN',
    'PALUSB',
    'PANCHB',
    'PANDBK',
    'PANIPT',
    'PATANB',
    'PATSCB',
    'PAYZAP',
    'PBGBBN',
    'PBGKOL',
    'PBGMPB',
    'PCBANK',
    'PCBDLK',
    'PCCBNK',
    'PCOBNK',
    'PCSBNK',
    'PCUBNK',
    'PGBSMS',
    'PIMSBI',
    'PITDCC',
    'PITOBK',
    'PMCBNK',
    'PMNSBM',
    'PMRYBK',
    'PMTYBK',
    'PNBACS',
    'PNBCCD',
    'PNBCRD',
    'PNBCRM',
    'PNBDBD',
    'PNBHRD',
    'PNBJNK',
    'PNBLKO',
    'PNBMKT',
    'PNBOTP',
    'PNBRTS',
    'PNBTBD',
    'PNNSBL',
    'PNSBKB',
    'PNSBNK',
    'POUCBK',
    'PPCBNK',
    'PPGDEP',
    'PRIBNK',
    'PRIMEB',
    'PRYBNK',
    'PSBANK',
    'PSBLTD',
    'PSCBNK',
    'PSTBNK',
    'PUBANK',
    'PUBBNK',
    'PUBLTD',
    'PUCBLL',
    'PUCBLM',
    'PUCBLP',
    'PUCBNK',
    'PUPGBK',
    'PURBNK',
    'PUSBNK',
    'PVIJAY',
    'RACBNK',
    'RAIBNK',
    'RAJABK',
    'RAJNAG',
    'RAMDCC',
    'RATNAK',
    'RAVISC',
    'RBISAY',
    'RBLBBB',
    'RBLCCC',
    'RBLCRD',
    'RBLHRD',
    'RBLINF',
    'RBLKYC',
    'RBLOFR',
    'RBLOSR',
    'RBLPIL',
    'RBLPLN',
    'RBLSSU',
    'RBLTEC',
    'RBLVPN',
    'RBLWCM',
    'RBOPEN',
    'RCBANK',
    'RCBRNG',
    'RCMSBN',
    'RCOBKL',
    'RIMUMB',
    'RMCBNK',
    'RMGBBK',
    'RMMBNR',
    'RMRBLY',
    'RNBASB',
    'RNBCRM',
    'RNBUPI',
    'RNSBAL',
    'RNSBBC',
    'RNSBKT',
    'RNSBLD',
    'RNSBLT',
    'RNSBMB',
    'RNSBMF',
    'RNSBNK',
    'RNUBNK',
    'ROATPM',
    'ROKDPA',
    'ROKDRI',
    'ROKRNL',
    'ROLUDH',
    'RONDYL',
    'RONELL',
    'RONELR',
    'ROONGL',
    'RORJPA',
    'RORURL',
    'ROTVPM',
    'ROUDPI',
    'ROVARN',
    'RPCOBL',
    'RPRDBK',
    'RSBANK',
    'RSBLPT',
    'RSSBBK',
    'RUBANK',
    'RUKBNK',
    'RUMBNK',
    'SACBNK',
    'SADHNA',
    'SAIBNK',
    'SAINIK',
    'SAMBNK',
    'SAMLMS',
    'SAMMCO',
    'SAMSAH',
    'SANDUR',
    'SANMTI',
    'SARNSB',
    'SAROBK',
    'SASCCB',
    'SATBNK',
    'SAVLIP',
    'SBALRT',
    'SBBJNB',
    'SBCDRE',
    'SBCWMS',
    'SBDBTL',
    'SBDCBK',
    'SBDCOG',
    'SBECOM',
    'SBEPAY',
    'SBEREG',
    'SBERIN',
    'SBERMS',
    'SBFIAH',
    'SBFIMF',
    'SBGALR',
    'SBGITC',
    'SBGLMS',
    'SBGMBS',
    'SBGPPC',
    'SBHART',
    'SBHIGH',
    'SBHINB',
    'SBHRMS',
    'SBIABD',
    'SBIABU',
    'SBIACS',
    'SBIADS',
    'SBIAHM',
    'SBIAND',
    'SBIAOR',
    'SBIAPP',
    'SBIATT',
    'SBIAVS',
    'SBIBAN',
    'SBIBHO',
    'SBIBHU',
    'SBIBOG',
    'SBIBSC',
    'SBIBTU',
    'SBICAA',
    'SBICAR',
    'SBICBG',
    'SBICDC',
    'SBICDS',
    'SBICHA',
    'SBICHD',
    'SBICHE',
    'SBICMD',
    'SBICMP',
    'SBICMS',
    'SBICON',
    'SBICOS',
    'SBICPA',
    'SBICPC',
    'SBICPP',
    'SBICRS',
    'SBICVC',
    'SBICVE',
    'SBICVS',
    'SBICWS',
    'SBIDAK',
    'SBIDBT',
    'SBIDCL',
    'SBIDEL',
    'SBIDGT',
    'SBIDIA',
    'SBIDMO',
    'SBIDMT',
    'SBIDRC',
    'SBIDRT',
    'SBIDSB',
    'SBIDTB',
    'SBIDYN',
    'SBIEES',
    'SBIEIS',
    'SBIEMM',
    'SBIEST',
    'SBIETC',
    'SBIETF',
    'SBIETM',
    'SBIEWS',
    'SBIFIJ',
    'SBIFMC',
    'SBIFOB',
    'SBIFRW',
    'SBIFXT',
    'SBIGAD',
    'SBIGCC',
    'SBIGKP',
    'SBIGLM',
    'SBIGLS',
    'SBIGMU',
    'SBIGOC',
    'SBIGRC',
    'SBIGUW',
    'SBIHOM',
    'SBIHRD',
    'SBIHSG',
    'SBIHUB',
    'SBIHYD',
    'SBIINF',
    'SBIITS',
    'SBIIVM',
    'SBIJAI',
    'SBIKBN',
    'SBIKBP',
    'SBIKER',
    'SBIKOL',
    'SBIKYC',
    'SBILCM',
    'SBILCO',
    'SBILKL',
    'SBILON',
    'SBILOS',
    'SBILOT',
    'SBILTP',
    'SBILUC',
    'SBILWF',
    'SBIMAB',
    'SBIMAH',
    'SBIMAP',
    'SBIMAT',
    'SBIMBD',
    'SBIMBS',
    'SBIMET',
    'SBIMFK',
    'SBIMUM',
    'SBINPA',
    'SBINPS',
    'SBINTH',
    'SBINWC',
    'SBINWD',
    'SBINZB',
    'SBIOEM',
    'SBIONB',
    'SBIOTP',
    'SBIOTS',
    'SBIPAY',
    'SBIPBS',
    'SBIPBU',
    'SBIPEN',
    'SBIPER',
    'SBIPNJ',
    'SBIPOS',
    'SBIPPC',
    'SBIPRM',
    'SBIPSP',
    'SBIQCK',
    'SBIRBH',
    'SBIRBU',
    'SBIRCH',
    'SBIRDH',
    'SBIREG',
    'SBIREH',
    'SBIRMD',
    'SBIRPR',
    'SBIRTI',
    'SBIRWZ',
    'SBISAM',
    'SBISBD',
    'SBISEC',
    'SBISFG',
    'SBISMA',
    'SBISMB',
    'SBISMC',
    'SBISME',
    'SBISMP',
    'SBISNB',
    'SBISNC',
    'SBISNP',
    'SBISOC',
    'SBISOM',
    'SBISRP',
    'SBITBU',
    'SBITDS',
    'SBITFF',
    'SBITFO',
    'SBITRB',
    'SBITRI',
    'SBITRN',
    'SBITRS',
    'SBITSM',
    'SBITSS',
    'SBITST',
    'SBIUDR',
    'SBIVMT',
    'SBIVPN',
    'SBIWAL',
    'SBIWEB',
    'SBJSMS',
    'SBLCPC',
    'SBLLMS',
    'SBLSOL',
    'SBLSPC',
    'SBMBNK',
    'SBMCB',
    'SBMCBK',
    'SBMCSH',
    'SBMINB',
    'SBMIND',
    'SBOCAS',
    'SBPBBU',
    'SBPINB',
    'SBRACC',
    'SBRLMS',
    'SBRWDZ',
    'SBSSBI',
    'SBTABK',
    'SBTINB',
    'SBWLTH',
    'SBYONO',
    'SCBANK',
    'SCDCCB',
    'SCOPBL',
    'SCSBNK',
    'SCUBLT',
    'SCUBNK',
    'SDCCBL',
    'SDCCBS',
    'SDCOBK',
    'SEVABK',
    'SGBBNK',
    'SGBBTI',
    'SGMCBL',
    'SGMUCB',
    'SHAHUB',
    'SHBIND',
    'SHGSMS',
    'SHIVBK',
    'SHSBLH',
    'SIBCNP',
    'SIBPRD',
    'SIBSMS',
    'SIDBIB',
    'SIKSBK',
    'SIWANB',
    'SJSBLH',
    'SKBANK',
    'SKNSBK',
    'SKNSBL',
    'SLMSBL',
    'SMBANK',
    'SMCBLT',
    'SMCBNK',
    'SMFLTD',
    'SMGPAY',
    'SMNBNK',
    'SMPBNK',
    'SMSBNK',
    'SMSSBK',
    'SMUCBK',
    'SMUCBL',
    'SMUCBS',
    'SNBHMT',
    'SNCOBL',
    'SNSBLS',
    'SNSBMS',
    'SNSBNK',
    'SOCINC',
    'SONBNK',
    'SPCBAK',
    'SPNSBK',
    'SPRCRD',
    'SPROFR',
    'SRGBBK',
    'SRIBNK',
    'SRKCOB',
    'SRYLTD',
    'SSBANK',
    'SSBFNK',
    'SSBKLP',
    'SSBMAN',
    'SSBMJA',
    'SSBMOD',
    'SSBNAG',
    'SSBNBL',
    'SSBPUN',
    'SSCORE',
    'SSFBNK',
    'SSKSBH',
    'SSKSBI',
    'SSKSBM',
    'SSKSBP',
    'SSKSBT',
    'SSNSBK',
    'SSNSBM',
    'SSSBKN',
    'SSSBNB',
    'SSSBNK',
    'SSSSBK',
    'STCBLR',
    'STELLA',
    'STNSBL',
    'SUBANK',
    'SUCBLS',
    'SUCNAG',
    'SUCOBK',
    'SUDBNK',
    'SUDHAB',
    'SUDICO',
    'SULBNK',
    'SUNBNK',
    'SUPRNA',
    'SURATB',
    'SUSSBN',
    'SUTEXB',
    'SUVKAS',
    'SVBANK',
    'SVCBNK',
    'SVCINF',
    'SVCTXN',
    'SWDEPT',
    'SWMUCB',
    'SWNCCB',
    'SYBGOV',
    'SYBKDC',
    'SYDBTL',
    'SYNBNK',
    'SYNBPR',
    'SYNDBK',
    'SYNDBT',
    'SYNDCT',
    'SYNDLN',
    'SYNDPG',
    'SYNEPB',
    'SYNIBD',
    'SYNINS',
    'SYNKSD',
    'SYNMOB',
    'SYNRBD',
    'SYNRUP',
    'SYNTAB',
    'SYNTST',
    'SYNVIG',
    'TADCBK',
    'TANCBL',
    'TBCBKL',
    'TBCOOP',
    'TBNSBL',
    'TBSBNK',
    'TBTCOB',
    'TBUCBK',
    'TCBMEH',
    'TCNSBK',
    'TCSBNK',
    'TCUBKK',
    'TCUBNK',
    'TDANCB',
    'TDCBBK',
    'TDCBNK',
    'TDCCBE',
    'TDCELL',
    'TECUBK',
    'TEHBIK',
    'TGBANK',
    'TGBATM',
    'TGBBNK',
    'TGBCBS',
    'TGBEBK',
    'TGBINB',
    'TGBMBS',
    'TGBTXN',
    'TGBUPI',
    'TGCUBK',
    'TGDCBT',
    'TGMCBK',
    'TGPCBK',
    'TGUCBK',
    'THIRUV',
    'THNSBL',
    'TJCCBL',
    'TJMSBL',
    'TJNSBK',
    'TJSBIB',
    'TJSBNK',
    'TJSBPM',
    'TJSBSB',
    'TJSBVV',
    'TKCUBL',
    'TKPCBL',
    'TKTCBK',
    'TKTCCB',
    'TKUBNK',
    'TKUCBL',
    'TLUBNK',
    'TMBANK',
    'TMBFST',
    'TMBOTP',
    'TMBUPI',
    'TMCCOB',
    'TMNSBL',
    'TMSCHT',
    'TMUCBL',
    'TNBLTD',
    'TNCCBK',
    'TNCCBNK',
    'TNJCBL',
    'TNJMSB',
    'TNMCBL',
    'TNSBLT',
    'TNSCBK',
    'TNYCBK',
    'TPMCBK',
    'TRBANK',
    'TRMUCB',
    'TSMCBK',
    'TSSKBK',
    'TTCOBK',
    'TUCBLD',
    'TVCBNK',
    'TVPCBK',
    'TVPCBL',
    'TYUBNK',
    'UBGBNK',
    'UBIBNK',
    'UBKGBK',
    'UBKGBM',
    'UCBANK',
    'UCBDHN',
    'UCTBNK',
    'UGBBNK',
    'UJVNBP',
    'UKASHI',
    'UKGBBK',
    'UMABNK',
    'UMACOB',
    'UMUCBK',
    'UMUCBL',
    'UNIXCE',
    'UNSBNK',
    'UPCBNK',
    'UPIPWD',
    'UPSBBK',
    'URBANK',
    'USCBNK',
    'UTGBBK',
    'UTKBNK',
    'UTKDBK',
    'UTKLGB',
    'UTKMIS',
    'UTKSBK',
    'UTKSFB',
    'UUCBUD',
    'UUNSBL',
    'VALSCB',
    'VARABK',
    'VASBNK',
    'VBANKL',
    'VCBANK',
    'VCCBNK',
    'VCNBNK',
    'VIDBBK',
    'VIDYBK',
    'VIJBNK',
    'VIKASB',
    'VIKBNK',
    'VKSBNK',
    'VMCBDC',
    'VMNBNK',
    'VNSBBR',
    'VNSBLK',
    'VSBANK',
    'VSBNKL',
    'VSPCCB',
    'VSVBNK',
    'VUCBKP',
    'VUCBNK',
    'VUVSBJ',
    'VVCCBK',
    'VVSBNK',
    'WANABK',
    'WASHIM',
    'WDCBNK',
    'WGLCCB',
    'WMBSMS',
    'WUCBKL',
    'WYDDCB',
    'YASHBK',
    'YDRVBK',
    'YESBCC',
    'YESBCM',
    'YESBNK',
    'YESPAY',
    'YUCBLY',
    'ZPSBNK',
    'ZSAGRA',
    'ZSBGZB',
    'ZSBJBK',
    'ZSBMRT',
    'ZSBRMP',
    // --- v1.2.0: SBI Card issuers + cooperative/Souharda credit banks
    // (curated from DLT header registry; insurers/MF/securities/NBFCs
    //  deliberately excluded to avoid non-transaction false positives) 
    '100001', '120001', '131313', '141414', 'ACHRYA', 'AKPSCC',
    'AKSHAY', 'ASCCSL', 'ASSCCL', 'BCCOSL', 'BTCCSL', 'DNRADH',
    'FINBUS', 'GNCCSL', 'GOSBIC', 'GUCCSL', 'KSSFCL', 'MCSSMY',
    'MTCCSM', 'MYSBIC', 'NISHNT', 'NUTCCS', 'PARIJT', 'PLMSCS',
    'RAMCSO', 'SBCCSE', 'SBCCSL', 'SBICAE', 'SBICAI', 'SBICAU',
    'SBICGV', 'SBICHR', 'SBICIT', 'SBICMR', 'SBICRD', 'SBICSR',
    'SBICTR', 'SBIOLA', 'SHUBHL', 'SKABIR', 'SSCCOL', 'SSCSSL',
    'SSNMCS', 'STRNDI', 'SVCCSB', 'SVMSCA', 'SVSCCL', 'TATACC',
    'TATACD', 'TATAMR', 'TKCCSL', 'TMCCLT', 'TULAJA', 'UDPVSS',
    'UJALAC', 'VCCSJ', 'VCCSJL', 'VJYSOU', 'VULCAN', 'WNSPLT',
  ];

  /// Merchant keywords for auto-categorization
  static const Map<String, List<String>> _merchantCategories = {
    'Food & Dining': [
      // --- Original ---
      'PLATOS', 'SWIGGY', 'ZOMATO', 'DOMINOS', 'TOING', 'MC DONALDS',
      'MCDONALDS', 'KFC', 'STARBUCKS', 'BURGER KING', 'PIZZA HUT', 'SUBWAY',
      'DUNKIN', 'CAFE COFFEE', 'CHAAYOS', 'HALDIRAM',
      // --- Appended ---
      'BARBEQUE NATION', 'BEHROUZ', 'FAASOS', 'OVEN STORY', 'EATCLUB',
      'THEOBROMA', 'WENDYS', 'COSTA COFFEE', 'TIM HORTONS', 'TACO BELL',
      'BIKANERVALA', 'SOCIAL', 'SMOKE HOUSE', 'PIZZAEXPRESS', 'MOCHA',
      'BARISTA', 'BASKIN ROBBINS', 'NATURALS ICE CREAM', 'PARADISE BIRYANI',
    ],
    'Groceries': [
      // --- Original ---
      'ZEPTO', 'BLINKIT', 'BIGBASKET', 'JIOMART', 'DMART', 'GROFERS', 'DUNZO',
      'INSTAMART', 'SWIGGY INSTAMART', 'MILKBASKET', 'LICIOUS',
      // --- Appended ---
      'NATURES BASKET', 'SPENCERS', 'MORE RETAIL', 'RELIANCE FRESH',
      'RELIANCE SMART', 'SMARTBAZAAR', 'BB DAILY', 'COUNTRY DELIGHT',
      'FRESH TO HOME', 'MEATIGO', 'TATA NEU', 'ONDC', 'SAHAKARI BHANDAR',
      'FRESHTOHOME', 'TENDER CUTS',
    ],
    'Shopping': [
      // --- Original ---
      'AMAZON', 'FLIPKART', 'MYNTRA', 'AJIO', 'MEESHO', 'SNAPDEAL', 'NYKAA',
      'TATA CLIQ', 'FIRSTCRY', 'LENSKART', 'CROMA',
      // --- Appended ---
      'RELIANCE DIGITAL', 'SHOPPERS STOP', 'LIFESTYLE', 'MAX FASHION',
      'PANTALOONS', 'WESTSIDE', 'DECATHLON', 'H&M', 'ZARA', 'RELIANCE TRENDS',
      'BEWAKOOF', 'PURPLLE', 'SUGAR COSMETICS', 'MYGLAMM', 'CHUMBAK',
      'PEPPERFRY', 'URBAN LADDER', 'TITAN', 'TANISHQ', 'KALYAN JEWELLERS',
      'MALABAR', 'IKEA', 'VIJAY SALES',
    ],
    'Travel': [
      // --- Original ---
      'IRCTC UTS',
      'IRCTC',
      'MAKEMYTRIP',
      'GOIBIBO',
      'CLEARTRIP',
      'YATRA',
      'Indian Railways Uts',
      'IXIGO',
      'REDBUS',
      'Mumbai Metro',
      'ABHIBUS',
      'EASEMYTRIP',
      'INDIGO',
      'SPICEJET',
      'AIRINDIA',
      // --- Appended ---
      'BOOKING.COM', 'AGODA', 'EXPEDIA', 'OYO', 'FABHOTELS', 'TREEBO',
      'VISTARA', 'AKASA AIR', 'AIR ASIA', 'CONFIRMTKT', 'PAYTM TICKET',
      'TICKETNEW', 'MMT', 'QATAR AIRWAYS', 'EMIRATES',
    ],
    'Transportation': [
      // --- Original ---
      'UBER', 'OLA', 'RAPIDO', 'MERU', 'METRO', 'DMRC',
      // --- Appended ---
      'BLABLACAR', 'INDRIVE', 'ZOOMCAR', 'REVV', 'BOUNCE', 'VOGO',
      'QUICK RIDE', 'UBERAUTO', 'OLA AUTO', 'CHALO', 'TUMMOC', 'NMMT',
      'BEST BUS', 'SMARTCARD', 'MAHA METRO', 'NASHIK METRO',
    ],
    'Entertainment': [
      // --- Original ---
      'NETFLIX', 'HOTSTAR', 'PRIME VIDEO', 'SPOTIFY', 'GAANA', 'SONY LIV',
      'ZEE5', 'BOOKMYSHOW', 'PVR', 'INOX',
      // --- Appended ---
      'JIO CINEMA', 'DISNEY+', 'APPLE TV', 'YOUTUBE PREMIUM', 'DISCOVERY+',
      'AUDIBLE', 'KUKU FM', 'POCKET FM', 'STORYTEL', 'PAYTM INSIDER',
      'CINEPOLIS', 'CARNIVAL CINEMAS', 'EPIC GAMES', 'STEAM', 'PLAYSTATION',
      'XBOX', 'NINTENDO',
    ],
    'Health & Medical': [
      // --- Original ---
      'APOLLO', 'PHARMEASY', 'NETMEDS', '1MG', 'TATA 1MG', 'PRACTO', 'CULT.FIT',
      // --- Appended ---
      'MEDPLUS', 'TRUEMEDS', 'APOLLO PHARMACY', 'THYROCARE', 'LAL PATHLABS',
      'SRL DIAGNOSTICS', 'METROPOLIS', 'HEALTHKART', 'MYPROTEIN', 'FITPASS',
      'CUREFIT', 'MAX HEALTHCARE', 'FORTIS', 'MEDANTA', 'MANIPAL',
    ],
    'Bills & Utilities': [
      // --- Original ---
      'AIRTEL', 'JIO', 'VI ', 'VODAFONE', 'BSNL', 'ELECTRICITY', 'BESCOM',
      'TATA POWER', 'DTH', 'TATA SKY', 'DISH TV',
      // --- Appended ---
      'MSEDCL', 'MAHAVITARAN', 'ADANI ELECTRICITY', 'TORRENT POWER', // Power
      'MGL',
      'IGL',
      'ADANI GAS',
      'GUJARAT GAS',
      'BHARAT GAS',
      'HP GAS',
      'INDANE', // Gas
      'ACT FIBERNET',
      'HATHWAY',
      'EXCITEL',
      'TIKONA',
      'JIOFIBER',
      'AIRTEL XSTREAM', // Broadband
      'FASTAG',
      'PAYTM FASTAG',
      'PARK+',
      'SUN DIRECT',
      'WATER BILL',
      'MUNICIPAL', // Misc
    ],
    'Education': [
      // --- Original ---
      'BYJU', 'UNACADEMY', 'VEDANTU', 'UPGRAD', 'COURSERA', 'UDEMY',
      // --- Appended ---
      'PHYSICS WALLAH', 'SIMPLILEARN', 'TOPPR', 'ALLEN', 'AAKASH', 'FIITJEE',
      'CHEGG', 'SKILLSHARE', 'EDX', 'DUOLINGO', 'SCRIBD', 'UNACADEMY',
      'SCALER', 'GREAT LEARNING', 'TESTBOOK',
    ],
  };

  /// Detect category from SMS message based on merchant keywords
  static String? detectCategory(String message) {
    final upperMessage = message.toUpperCase();

    for (final entry in _merchantCategories.entries) {
      for (final merchant in entry.value) {
        if (upperMessage.contains(merchant)) {
          return entry.key;
        }
      }
    }

    if (upperMessage.contains('SALARY') || upperMessage.contains('PAYROLL'))
      return 'Salary';
    if (upperMessage.contains('REFUND') || upperMessage.contains('REVERSAL'))
      return 'Refund';

    return null;
  }

  /// Strip the DLT routing parts from a sender ID, leaving the stable
  /// bank header that `_bankSenderPatterns` actually lists.
  ///
  /// Indian SMS senders arrive as `<operator+circle>-<header>[-<route>]`,
  /// e.g. "BV-SBIUPI-S", "JD-MAHABK", "AD-SBIINB-T". The 2-char prefix
  /// changes with the user's telecom operator and circle, and the 1-char
  /// suffix (S/T/P/G, mandated since 2024) varies by message route — only
  /// the middle header is stable per bank.
  static String normalizeSender(String sender) {
    var s = sender.trim().toUpperCase();
    s = s.replaceFirst(RegExp(r'-[A-Z]$'), ''); // route suffix: "-S", "-T"...
    s = s.replaceFirst(RegExp(r'^[A-Z]{2}-'), ''); // operator+circle prefix
    return s;
  }

  /// TRAI DLT route suffix of a sender ("VM-HDFCBK-P" → "P"), or null when
  /// the sender uses the old suffix-less format.
  static String? routeSuffix(String sender) {
    final match = RegExp(r'-([A-Z])$').firstMatch(sender.trim().toUpperCase());
    return match?.group(1);
  }

  /// Check if the SMS is from a bank.
  ///
  /// Matching is strict: the sender must correspond to a known bank header.
  /// There is deliberately no "looks like a DLT sender" fallback — that let
  /// any college/store/OTT sender through, and a scholarship or promo SMS
  /// mentioning an amount would be logged as a transaction.
  static bool isBankSms(String sender) {
    // Route suffix: -S (service) and -T (transactional) carry genuine bank
    // alerts, -G carries government DBT credits. -P is promotional by
    // regulation and never a real transaction — drop it outright, even from
    // a real bank header.
    if (routeSuffix(sender) == 'P') return false;

    final upperSender = sender.toUpperCase();
    final coreHeader = normalizeSender(sender);

    return _bankSenderPatterns.any(
          (pattern) =>
              coreHeader == pattern || upperSender.contains(pattern),
        ) ||
        // Full-name senders ("Bank of Maharashtra") and bank headers the
        // list may miss — still subject to the -P rejection above.
        upperSender.contains('BANK');
  }

  /// Parse an SMS message to extract transaction details
  /// Returns null if the message is not a valid transaction SMS
  static TransactionModel? parseTransaction(
    String sender,
    String message,
    DateTime receivedAt,
  ) {
    if (!isBankSms(sender)) return null;

    final upperMessage = message.toUpperCase();

    // Skip non-transaction messages
    if (_isNonTransactionMessage(upperMessage)) return null;

    // Determine transaction type
    final type = _getTransactionType(upperMessage);
    if (type == null) return null;

    // Extract amount
    final amount = _extractAmount(message);
    if (amount == null || amount <= 0) return null;

    // Extract account info
    final accountInfo = _extractAccountInfo(message);

    // Extract merchant/payee name from SMS body
    final merchantName = _extractMerchant(message, accountInfo);

    // Auto-detect category from merchant
    final category = detectCategory(message);

    return TransactionModel(
      amount: amount,
      type: type,
      sender: sender,
      message: message,
      detectedAt: receivedAt,
      accountInfo: accountInfo,
      merchantName: merchantName,
      category: category,
      // A hit against the curated merchant database (or a salary/refund
      // keyword) is a confident match, so mark it classified instead of
      // leaving it in the "Unclassified" queue for the user to confirm.
      // Merchants we can't recognise stay unclassified as before.
      isClassified: category != null,
    );
  }

  /// Regex matching a completed-transaction verb. Used to decide whether a
  /// message that contains promo/security keywords is still a real
  /// debit/credit alert (PSU banks append "Download YONO", "Never share
  /// OTP/PIN", "...your registered mobile" footers to genuine alerts).
  /// "DEBIT BY/OF" covers SBI's "has a debit by transfer of Rs X" phrasing
  /// while staying narrower than \bDEBIT\b, which would match "debit card"
  /// in OTP messages.
  static final RegExp _transactionVerbRegex = RegExp(
    r'\b(?:DEBITED|CREDITED|WITHDRAWN|DEPOSITED|SPENT|TRANSFERRED|TRF|(?:DEBIT|CREDIT)\s+(?:BY|OF|FOR|WITH))\b',
  );

  /// Check if this is a non-transaction message (OTP, alerts, etc.)
  static bool _isNonTransactionMessage(String upperMessage) {
    // Hard rejects: these messages are never completed transactions, even
    // when they mention amounts or words like "debited".
    final hardRejectPatterns = <RegExp>[
      RegExp(r'\bSTATEMENT\b'),
      RegExp(r'BILL GENERATED'),
      RegExp(r'MINIMUM\s+(?:AMOUNT\s+)?DUE'),
      RegExp(r'\bMIN\.?\s+(?:AMT\.?\s+)?DUE\b'),
      // Autopay/mandate reminders for future debits
      RegExp(r'WILL BE DEBITED'),
      RegExp(r'\bAUTOPAY\b'),
      RegExp(r'E-?MANDATE'),
      // UPI collect requests — money has not moved yet
      RegExp(r'HAS REQUESTED'),
      RegExp(r'COLLECT REQUEST'),
      RegExp(r'PAYMENT REQUEST'),
      // Failed/declined attempts
      RegExp(r'\bFAILED\b'),
      RegExp(r'\bDECLINED\b'),
      RegExp(r'INSUFFICIENT'),
      // Card lifecycle / security notices
      RegExp(r'CARD\s+(?:IS\s+)?BLOCKED'),
      RegExp(r'CARD\s+(?:IS\s+)?ACTIVATED'),
      RegExp(r'PASSWORD CHANGED'),
      RegExp(r'\bLOGIN\b'),
      RegExp(r'LOGGED IN'),
      // Credit-limit-increase offers. Banks (notably ICICI) send these on the
      // transactional -S/-T route, so the -P promo filter misses them — and
      // the "from Rs X to Rs Y" limit was being read as a ₹X income credit.
      RegExp(r'INCREAS(?:E|ING)\s+(?:THE\s+|YOUR\s+)?(?:CREDIT\s+)?LIMIT'),
      RegExp(r'RAISE\s+(?:THE\s+|YOUR\s+)?(?:CREDIT\s+)?LIMIT'),
      RegExp(r'\bCRLIM\b'),
      // Credit-card bill payment received — this is the user *repaying* their
      // card, not income. The spends were already captured when the card was
      // used, and the bank-side debit for the payment is the real outflow.
      // e.g. "Payment of INR X has been received on your ... Credit Card ...".
      RegExp(r'PAYMENT[\s\S]{0,60}RECEIVED[\s\S]{0,60}CREDIT\s*CARD'),
    ];
    if (hardRejectPatterns.any((p) => p.hasMatch(upperMessage))) {
      return true;
    }

    // Soft rejects: these words flag OTPs and marketing SMS, but banks also
    // put them in footers of genuine alerts. Only reject when the message
    // carries no completed-transaction verb. 'PIN' is word-bounded so it no
    // longer matches inside SHOPPING / PINELABS etc.
    final softRejectPatterns = <RegExp>[
      RegExp(r'\bOTP\b'),
      RegExp(r'ONE TIME PASSWORD'),
      RegExp(r'VERIFICATION CODE'),
      RegExp(r'\bPIN\b'),
      RegExp(r'\bCVV\b'),
      RegExp(r'UPDATED YOUR'),
      RegExp(r'\bREGISTERED\b'),
      RegExp(r'\bLINKED\b'),
      RegExp(r'REWARD POINTS'),
      RegExp(r'CASHBACK EARNED'),
      RegExp(r'\bOFFER\b'),
      RegExp(r'\bPROMO\b'),
      RegExp(r'\bDISCOUNT\b'),
      RegExp(r'DUE DATE'),
    ];
    final hasTransactionVerb = _transactionVerbRegex.hasMatch(upperMessage);
    if (!hasTransactionVerb &&
        softRejectPatterns.any((p) => p.hasMatch(upperMessage))) {
      return true;
    }

    return false;
  }

  /// Determine if it's a credit or debit transaction using weighted scoring
  static TransactionType? _getTransactionType(String upperMessage) {
    // SPECIAL CASE: outgoing transfer / debit.
    // An explicit "your account was debited" marker is an unambiguous
    // outflow, so classify as DEBIT immediately — even when the same SMS
    // also says a payee was "credited" (that "credited" refers to the
    // recipient, not to you). This single rule covers UPI/transfer wording
    // across banks and replaces the earlier per-bank debit boosts:
    //   ICICI: "A/c XX debited for Rs X; PAYEE credited"
    //   SBI:   "A/C debited by 35.0 ... trf to PAYEE"
    //   BOM:   "a/c is debited for Rs X ..."
    //   older: "Rs X debited ... and credited to PAYEE"
    final accountDebited =
        RegExp(r'\bDEBITED\s+(?:FOR|BY|WITH|FROM)\b').hasMatch(upperMessage) ||
            upperMessage.contains('IS DEBITED');
    if (accountDebited ||
        (upperMessage.contains('DEBITED') &&
            (upperMessage.contains('CREDITED TO') ||
                upperMessage.contains('AND CREDITED')))) {
      return TransactionType.debit;
    }

    // SPECIAL CASE: Money received pattern
    // "Rs.X credited... from [sender]" or "received from" = This is a CREDIT
    if ((upperMessage.contains('CREDITED') ||
            upperMessage.contains('RECEIVED')) &&
        upperMessage.contains(' FROM ') &&
        !upperMessage.contains('DEBITED')) {
      return TransactionType.credit;
    }

    // Strong indicators - these are definitive keywords
    final strongDebitKeywords = [
      'DEBITED',
      'DEBITED FROM',
      'DEBIT BY',
      'DEBIT OF',
      'WITHDRAWN',
      'SPENT',
      'DR.',
      'DR ',
      'ATM WDL',
      'MONEY SENT',
      'SENT TO',
      'PAID TO',
      'TRANSFERRED TO',
    ];

    final strongCreditKeywords = [
      'CREDITED',
      'CREDIT BY',
      'CREDIT OF',
      'RECEIVED',
      'DEPOSITED',
      'CR.',
      'CR ',
      'MONEY RECEIVED',
      'RECEIVED FROM',
      'CREDITED FROM',
      'REFUND',
      'CASHBACK',
      'REVERSAL',
      'REVERSED',
    ];

    // Weak indicators - these could appear in either context
    final weakDebitKeywords = [
      'PAID',
      'TRANSFERRED',
      'PURCHASE',
      'PAYMENT',
      'SENT',
      'TXN',
      'TRANSACTION',
      'VIA UPI',
    ];

    final weakCreditKeywords = ['ADDED', 'CREDIT'];

    int debitScore = 0;
    int creditScore = 0;

    // Check strong keywords first (weight: 10 points)
    for (final keyword in strongDebitKeywords) {
      if (upperMessage.contains(keyword)) {
        debitScore += 10;
      }
    }

    for (final keyword in strongCreditKeywords) {
      if (upperMessage.contains(keyword)) {
        creditScore += 10;
      }
    }

    // HDFC-style: "Sent Rs.X" at beginning is a strong debit
    if (RegExp(r'^\s*SENT\s+RS', caseSensitive: false).hasMatch(upperMessage)) {
      debitScore += 15;
    }

    // SBI-style: "UPI frm A/c" is a strong debit (money going from your account)
    if (upperMessage.contains('UPI FRM') || upperMessage.contains('UPI FROM')) {
      debitScore += 15;
    }

    // Note: explicit "debited for/by/with/from" and "is debited" wording is
    // already resolved to a debit by the outflow special case above.

    // If we have a clear winner from strong keywords, return immediately
    if (debitScore > 0 && creditScore == 0) {
      return TransactionType.debit;
    }
    if (creditScore > 0 && debitScore == 0) {
      return TransactionType.credit;
    }

    // Check weak keywords (weight: 2 points)
    for (final keyword in weakDebitKeywords) {
      if (upperMessage.contains(keyword)) {
        debitScore += 2;
      }
    }

    for (final keyword in weakCreditKeywords) {
      if (upperMessage.contains(keyword)) {
        creditScore += 2;
      }
    }

    // Context-based adjustments for UPI/IMPS transfers
    // Pattern: "to [name]" suggests money going OUT (debit)
    if (RegExp(r'\bTO\s+[A-Z]').hasMatch(upperMessage)) {
      debitScore += 5;
    }

    // Pattern: "from [name]" without debited suggests money coming IN (credit)
    if (RegExp(r'\bFROM\s+[A-Z]').hasMatch(upperMessage) &&
        !upperMessage.contains('DEBITED')) {
      creditScore += 5;
    }

    // Determine result based on scores
    if (debitScore > creditScore) {
      return TransactionType.debit;
    } else if (creditScore > debitScore) {
      return TransactionType.credit;
    }

    // If scores are equal and both > 0, favor debit (more common in banking SMS)
    if (debitScore > 0 && creditScore > 0) {
      return TransactionType.debit;
    }

    return null;
  }

  /// Extract amount from the message
  static double? _extractAmount(String message) {
    // Strip balance fragments ("Avl Bal Rs.12,345.67", "Bal: INR 5000") so
    // the generic currency patterns below never pick up the account balance
    // instead of the transaction amount.
    final cleaned = message.replaceAll(
      RegExp(
        r'(?:(?:AVL|AVBL|AVL?BL|AVAILABLE|TOTAL|CLR|CLEAR)\.?\s*)?BAL(?:ANCE)?\.?\s*(?:IS|:|-)?\s*(?:RS\.?|INR|₹)?\s*[\d,]+(?:\.\d+)?',
        caseSensitive: false,
      ),
      ' ',
    );

    // Patterns to match amounts in various formats, most specific first
    final patterns = [
      // Verb-anchored with optional currency marker — covers SBI's bare
      // format "debited by 35.0" / "credited by 120.0" (no Rs/INR at all)
      RegExp(
        r'(?:DEBITED|CREDITED)\s+(?:BY|FOR|WITH)\s+(?:RS\.?|INR|₹)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      // Rs. 1,234.56 or Rs 1234.56 or Rs.1234 (\b keeps "48 HRS 1800..."
      // from matching as an amount)
      RegExp(r'\bRS\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // INR 1,234.56 or INR1234
      RegExp(r'\bINR\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // ₹1,234.56 or ₹ 1234
      RegExp(r'₹\s*([\d,]+\.?\d*)'),
      // Rupees 1234
      RegExp(r'\bRUPEES?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // Amount: 1234.56 or Amt: 1234
      RegExp(r'\bAMT\.?:?\s*RS?\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // for Rs.1234 (specific format)
      RegExp(r'(?:FOR|OF)\s+RS\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        // Remove commas and parse
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extract account information (last 4 digits of account/card)
  static String? _extractAccountInfo(String message) {
    // Patterns to match account numbers
    final patterns = [
      // A/c XX1234 / A/c No. XX1234 / Acct XX1234 / Ac XXXXXX1234, and also a
      // fully unmasked number like Saraswat's "A/c no. 000404". The trailing
      // `\d*(\d{4})` captures the LAST four digits of the account run (the
      // convention banks display), so "000404" yields 0404, not 0004.
      RegExp(
        r'A/?C(?:CT)?\.?\s*(?:NO\.?)?\s*[X*]*\d*(\d{4})',
        caseSensitive: false,
      ),
      // Letter-masked account with no X/* mask, e.g. IDBI "A/c NN15983" → last
      // four of the trailing digit run. The mask letters must butt directly
      // against the digits, so this can't latch onto a word + nearby amount.
      RegExp(
        r'A/?C\.?\s*(?:NO\.?)?\s*[A-Z]{1,4}\d*(\d{4})',
        caseSensitive: false,
      ),
      // Account ending 1234 or Account XX1234
      RegExp(r'ACCOUNT\s*(?:ENDING)?\s*[X*]*([\d]{4})', caseSensitive: false),
      // Card XX1234 or Card ending 1234
      RegExp(
        r'CARD\s*(?:ENDING|NO\.?)?\s*[X*]*([\d]{4})',
        caseSensitive: false,
      ),
      // a/c **1234 or a/c *1234 (Axis, Kotak style)
      RegExp(r'A/?C\s*\*+([\d]{4})', caseSensitive: false),
      // **1234 or XX1234 followed by typical separators
      RegExp(r'[X*]{2,}([\d]{4})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        return 'XX${match.group(1)}';
      }
    }

    return null;
  }

  /// Public static method to extract merchant from a message.
  /// Used by DatabaseService during backfill operations.
  static String? extractMerchantStatic(String message, String? accountInfo) {
    return _extractMerchant(message, accountInfo);
  }

  /// Extract merchant/payee name from the SMS body.
  ///
  /// Tries multiple bank-specific and generic patterns. Falls back to
  /// the account number if no merchant name can be determined.
  ///
  /// Priority order:
  /// 1. ICICI Info: field — `Info: UPI-RefNo-MerchantName`
  /// 1b. Kotak — `Sent ... to {PAYEE} on {date}` (VPA or name)
  /// 2. BOI/generic — `credited to {NAME} via UPI`
  /// 3. HDFC — `To {NAME}` (on same or next line)
  /// 4. Generic — `paid/sent/transferred/payment/trf to {NAME}` (BOM, SBI)
  /// 5. UPI VPA — `VPA {name}@bank` or `{name}@{bank}` → extract name
  /// 6. Axis — `to VPA {name}@{bank}`
  /// 7. Fallback — account number (A/cXX1234)
  static String? _extractMerchant(String message, String? accountInfo) {
    String? merchant;

    // --- Pattern 1: ICICI "Info:" field ---
    // "Info: UPI-123456789012-MerchantName"
    // "Info: UPI/123456789012/MerchantName"
    final infoMatch = RegExp(
      r'Info:\s*UPI[-/]\d+[-/](.+?)(?:\.|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (infoMatch != null) {
      merchant = _cleanMerchant(infoMatch.group(1));
      if (merchant != null) return merchant;
    }

    // --- Pattern 1b: Kotak "Sent ... to {PAYEE} on {date}" ---
    // Kotak's UPI debit alerts read:
    //   "Sent Rs.60.00 from Kotak Bank AC X9883 to paytm.s21upj5@pty on
    //    27-06-26. UPI Ref 617835353944. Not you, https://kotak.com/..."
    // The counterparty sits between "to" and " on <date>". The generic
    // "sent to {NAME}" rule (Pattern 4) misses it because "Sent" and "to"
    // are split by the "from ... AC ..." clause, and the VPA handle (@pty)
    // isn't in Pattern 5's recognised-handle list — so these debits fell
    // through to the account-number fallback, leaving payee == account and
    // breaking per-merchant tagging. Scoped to Kotak so no other bank moves.
    // (Kotak credits read "... from {PAYER} on ..." with no "to {X} on", so
    // they are left to Pattern 5 exactly as before.)
    if (RegExp(r'\bKotak\b', caseSensitive: false).hasMatch(message)) {
      final kotakTo = RegExp(r'\bto\s+(.+?)\s+on\b', caseSensitive: false)
          .firstMatch(message);
      final candidate = kotakTo?.group(1)?.trim();
      if (candidate != null && candidate.length > 2) {
        // A UPI VPA ("paytm.s21upj5@pty") → render its handle-less local
        // part the same way Pattern 5 does ("name.tag" → "Name Tag").
        final vpa = RegExp(r'^([\w.\-]+)@[\w.\-]+$').firstMatch(candidate);
        if (vpa != null) {
          final local = vpa.group(1)!.replaceAll(RegExp(r'[._]'), ' ').trim();
          if (local.isNotEmpty) return _titleCase(local);
        }
        // Otherwise it's a plain name ("to JOHN DOE on ...").
        merchant = _cleanMerchant(candidate);
        if (merchant != null) return merchant;
      }
    }

    // --- Pattern 2: BOI "credited to {NAME} via UPI" ---
    // "debited...and credited to KIRTI PRAHALAD PANCHAL via UPI"
    final creditedToVia = RegExp(
      r'credited\s+to\s+(.+?)\s+via\b',
      caseSensitive: false,
    ).firstMatch(message);
    if (creditedToVia != null) {
      merchant = _cleanMerchant(creditedToVia.group(1));
      if (merchant != null) return merchant;
    }

    // --- Pattern 3: HDFC "To {NAME}" ---
    // "Sent Rs.30.00\nFrom HDFC Bank A/C *9463\nTo Mumbai Metro Ghatkopar"
    final toPattern = RegExp(
      r'(?:^|\n)\s*To\s+(.+?)(?:\n|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (toPattern != null) {
      final candidate = toPattern.group(1)?.trim();
      // Make sure it's not "To block" or "To 7308080808" (instruction text)
      if (candidate != null &&
          candidate.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(candidate) &&
          !candidate.toUpperCase().startsWith('BLOCK') &&
          !candidate.toUpperCase().startsWith('REPORT')) {
        merchant = _cleanMerchant(candidate);
        if (merchant != null) return merchant;
      }
    }

    // --- Pattern 4: Generic "paid/sent/transferred/payment to {NAME}" ---
    // Covers BOM's "for UPI payment to SANTOSH ANANT G on 10-Jun-26" and
    // SBI's "trf to RAMESH KUMAR Refno ...". The name runs until the next
    // structural token — a date ("on"), "via", a ref/RRN number, or
    // punctuation — so trailing "on <date>. RRN: ..." is not captured.
    // Avoid matching "sent to 9215676766" or "call to ..." (digits-only and
    // BLOCK/REPORT candidates are rejected below).
    final paidTo = RegExp(
      r'(?:paid|sent|transferred|transfer|trf|payment)\s+to\s+(.+?)(?:\s*\.|,|\s+on\b|\s+via\b|\s+ref\b|\s+refno\b|\s+rrn\b|\n|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (paidTo != null) {
      final candidate = paidTo.group(1)?.trim();
      if (candidate != null &&
          candidate.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(candidate) &&
          !candidate.toUpperCase().startsWith('BLOCK')) {
        merchant = _cleanMerchant(candidate);
        if (merchant != null) return merchant;
      }
    }

    // --- Pattern 4b: slash-delimited UPI ref carrying the counterparty name ---
    // Co-op / PSU credits embed the payer inside the UPI ref instead of a
    // "from {NAME}" clause, e.g. Saraswat's
    //   "...credited with INR 150.00 ... towards UPI/340983713462/HUSAIN M N/SR."
    // The name is the segment right after UPI/<digits>/, ending at the next
    // slash, stop, comma, or " on <date>". Requiring a letter-led run of
    // letters/spaces/dots keeps it from latching onto numeric refs or VPA codes.
    final upiRefName = RegExp(
      r'\bUPI[/-]\d+[/-]([A-Za-z][A-Za-z .]{2,}?)(?:[/-]|\.|,|\s+on\b|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (upiRefName != null) {
      merchant = _cleanMerchant(upiRefName.group(1));
      if (merchant != null) return merchant;
    }

    // --- Pattern 5: UPI VPA in body ---
    // "to VPA username@okaxis" or just "username@okaxis" or "username@ybl"
    final vpaPatterns = [
      // "to VPA username@bank"
      RegExp(r'(?:to\s+)?VPA\s+([\w.]+)@[\w.]+', caseSensitive: false),
      // Standalone UPI VPA like "username@okaxis", "name@ybl", "name@paytm"
      RegExp(
        r'\b([\w.]{3,})@(?:ok(?:axis|icici|sbi|hdfc)|ybl|paytm|upi|apl|ibl|axl|sbi|okhdfcbank|okbizaxis)\b',
        caseSensitive: false,
      ),
    ];
    for (final vpaRegex in vpaPatterns) {
      final vpaMatch = vpaRegex.firstMatch(message);
      if (vpaMatch != null) {
        final vpaName = vpaMatch.group(1);
        if (vpaName != null && vpaName.length > 2) {
          // Clean up VPA name: replace dots/underscores with spaces, title case
          final cleaned = vpaName.replaceAll(RegExp(r'[._]'), ' ').trim();
          if (cleaned.isNotEmpty) {
            return _titleCase(cleaned);
          }
        }
      }
    }

    // --- Pattern 6: "by UPI Ref No" with merchant in preceding text ---
    // BOM: "debited by Rs 500.00 on 30-05-26 by UPI Ref No 123456789012"
    // No merchant info available here, fall through

    // --- Pattern 7: Bank of Maharashtra credit "...from {NAME} RRN:" ---
    // BOM credits read: "A/c XX7763 credited with Rs. 453.00 on 01-Jul-26
    // from Miss AISHWARYA RRN: 125560855601 -Bank of Maharashtra". The payer
    // name sits between "from" and the RRN/ref/footer, and none of the
    // patterns above catch it, so these credits fell through to the account
    // number. Scoped to BOM credits (message names the bank AND says
    // "credited") so the generic "from" wording in other banks — and BOM's
    // own debits, which say "debited" — is left untouched.
    final isBomCredit =
        RegExp(r'bank\s+of\s+maharashtra', caseSensitive: false)
                .hasMatch(message) &&
            RegExp(r'\bcredited\b', caseSensitive: false).hasMatch(message);
    if (isBomCredit) {
      final fromName = RegExp(
        r'\bfrom\s+([A-Za-z][A-Za-z. ]+?)'
        r'(?:\s+RRN\b|\s+Ref(?:\s*No)?\b|\s+UTR\b|\s*[-.,]|\s+on\b|\n|$)',
        caseSensitive: false,
      ).firstMatch(message);
      if (fromName != null) {
        merchant = _cleanMerchant(fromName.group(1));
        if (merchant != null) return merchant;
      }
    }

    // --- Fallback: Use account number as merchant identifier ---
    if (accountInfo != null && accountInfo.isNotEmpty) {
      return accountInfo;
    }

    return null;
  }

  /// Clean up extracted merchant string
  static String? _cleanMerchant(String? raw) {
    if (raw == null) return null;

    // Trim whitespace and trailing punctuation
    var cleaned = raw.trim().replaceAll(RegExp(r'[.,;:!\s]+$'), '');

    // Remove trailing "Ref" or "Ref No" fragments
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\s*Ref(?:\s*No)?\.?\s*\d*\s*$', caseSensitive: false),
          '',
        )
        .trim();

    // Remove phone numbers and "call/SMS/click" instructions
    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'\s*(?:call|sms|click|fwd|forward)\s.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Remove "Not You?" or "If not done by u" trailing text
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\s*(?:Not\s*You|If\s+not).*$', caseSensitive: false),
          '',
        )
        .trim();

    // If too short or just numbers, return null
    if (cleaned.length < 2 || RegExp(r'^\d+$').hasMatch(cleaned)) {
      return null;
    }

    return _titleCase(cleaned);
  }

  /// Title-case a string: "MUMBAI METRO GHATKOPAR" → "Mumbai Metro Ghatkopar"
  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
