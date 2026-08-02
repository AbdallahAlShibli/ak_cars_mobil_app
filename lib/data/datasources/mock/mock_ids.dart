/// Frozen GUIDs for every record in the demo dataset.
///
/// Each of these is a real, hand-generated v4 GUID, written out once and
/// never regenerated — the whole point is that they are *constant*. Tests
/// assert against them, the seed cross-references them, and a value that
/// changed between runs would break both.
///
/// **Why the demo data uses GUIDs at all.** Every record in this app is
/// identified by a GUID, because that is what the database's primary key
/// is. Demo records that used readable ids (`p1`, `express`, `g7`) were the
/// last place where an id meant something you could read, and that is exactly
/// what made them dangerous: code drifted into switching on them. Making the
/// demo data indistinguishable from server data removes the temptation and
/// makes the mock and API paths genuinely interchangeable.
///
/// **The readable name lives in the constant, not in the value.** `mockIdP3`
/// is as easy to follow at a call site as `'p3'` was, and it is the only
/// spelling of that id in the codebase — so there is no literal to typo and
/// no second place to update.
///
/// Where a record's *kind* still has to be recognised in code — a tyre
/// service is a tyre service — that is a `slug`, not an id. See
/// `ServiceCategory.slug`.
library;

import '../../../core/utils/guid.dart';

// ------------------------------------------------------------------------
// Service categories
// ------------------------------------------------------------------------


/// `ac` in the previous readable scheme.
const String mockIdAc = '6b49ad82-b20d-40cd-a4e3-744ad96bb359';
/// `battery` in the previous readable scheme.
const String mockIdBattery = 'ffb5e37e-a47e-4e4d-aad4-6aa8278f0fe4';
/// `contracts` in the previous readable scheme.
const String mockIdContracts = '3ed3bdf6-77f2-48ae-a4f3-6db85e852d46';
/// `detailing` in the previous readable scheme.
const String mockIdDetailing = '5695b46e-aca5-4bfe-b7ec-074c3ca57a66';
/// `diag` in the previous readable scheme.
const String mockIdDiag = '7acf4d27-ce2a-48ee-9189-f91234297d62';
/// `ev-battery` in the previous readable scheme.
const String mockIdEvBattery = '86d73108-7bfa-4880-a771-5fcd92ca1d43';
/// `ev-charger` in the previous readable scheme.
const String mockIdEvCharger = 'e9b5d1fe-1a9e-466f-bc1a-3b556ad520ca';
/// `ev-charging` in the previous readable scheme.
const String mockIdEvCharging = '1b719a3f-d77c-4845-8095-44bfa91c291e';
/// `ev-check` in the previous readable scheme.
const String mockIdEvCheck = '2d7ea0d1-d3db-4dab-ae97-2b947acfbe82';
/// `ev-sos` in the previous readable scheme.
const String mockIdEvSos = '2988a39b-5f2f-4195-bbe8-75a684d98b19';
/// `express` in the previous readable scheme.
const String mockIdExpress = '96a14923-7c29-424c-bcaf-493872ca92dd';
/// `full` in the previous readable scheme.
const String mockIdFull = '5cf7c631-e47c-4c80-98b1-45497beb12da';
/// `major` in the previous readable scheme.
const String mockIdMajor = '730c656b-9bf8-4297-b59e-61b0336ed016';
/// `repair` in the previous readable scheme.
const String mockIdRepair = 'ca876cf7-9bd4-4eae-af46-292279b056c1';
/// `sos` in the previous readable scheme.
const String mockIdSos = '89959eaa-4514-4687-8f24-63104ade2e4d';
/// `tyres` in the previous readable scheme.
const String mockIdTyres = 'cb6c1dd8-44f9-4cc2-80f4-f7e5aad52825';

// ------------------------------------------------------------------------
// Workshops (service providers)
// ------------------------------------------------------------------------


/// `p1` in the previous readable scheme.
const String mockIdP1 = '5d198671-9a74-4389-b8bf-7e08799d8207';
/// `p2` in the previous readable scheme.
const String mockIdP2 = 'a018e035-dcbd-4a04-bd26-dfc385d8634f';
/// `p3` in the previous readable scheme.
const String mockIdP3 = 'f7bec8e4-040f-41c0-8e42-5f452ea9cd73';
/// `p4` in the previous readable scheme.
const String mockIdP4 = 'd8e94661-6f50-4359-b83f-3556c1ec9736';
/// `p5` in the previous readable scheme.
const String mockIdP5 = 'd9e00f02-6648-4b42-83ee-1a5187d7c9c8';
/// `p6` in the previous readable scheme.
const String mockIdP6 = '3d45dee7-cd0c-4eb4-b1f2-cf36202110ba';
/// `p7` in the previous readable scheme.
const String mockIdP7 = '43e370e3-01c5-4bbd-8371-7832ca9f6d72';
/// `p8` in the previous readable scheme.
const String mockIdP8 = '9c6bbf3e-35ce-411b-8ca7-3c6bef3afbc7';
/// `p9` in the previous readable scheme.
const String mockIdP9 = 'e2b18b45-60f9-4e80-b9d2-5c5d7eacde77';
/// `p10` in the previous readable scheme.
const String mockIdP10 = 'a6dee62b-4a44-4633-b9a4-d01714150f55';
/// `p11` in the previous readable scheme.
const String mockIdP11 = '67387efa-a7e6-4113-a237-9d309c01817a';
/// `p12` in the previous readable scheme.
const String mockIdP12 = 'af47eb5d-427f-4613-9e60-5754607cfbb5';
/// `p13` in the previous readable scheme.
const String mockIdP13 = '7dfb4272-ca5e-4540-b7a2-0fcc86b153bf';
/// `p14` in the previous readable scheme.
const String mockIdP14 = '3980c532-eb2d-4f97-aa07-7ced481351d0';
/// `p15` in the previous readable scheme.
const String mockIdP15 = '8a09b9b3-212e-4154-9d38-765a81598dde';

// ------------------------------------------------------------------------
// Service requests (bookings)
// ------------------------------------------------------------------------


/// `2101` in the previous readable scheme.
const String mockId2101 = 'ff46c142-9514-45f2-aebb-fbfd89a135eb';
/// `2102` in the previous readable scheme.
const String mockId2102 = '0a4d6f96-c3f3-47c6-ba6e-1fb29cb36320';
/// `2103` in the previous readable scheme.
const String mockId2103 = '3a7a97f1-1086-4287-a4fb-f3a1f6cace64';
/// `2104` in the previous readable scheme.
const String mockId2104 = 'b5913268-fc53-499b-ae43-041f794021b4';
/// `2105` in the previous readable scheme.
const String mockId2105 = 'b75b21f5-a20d-447a-9c8d-799270ea2c1c';
/// `2106` in the previous readable scheme.
const String mockId2106 = 'c82f2bf6-01ca-4e21-90e8-96aa5889ac0d';
/// `2107` in the previous readable scheme.
const String mockId2107 = '01c7456c-52d5-452d-8ca7-2ac7e4b7545d';
/// `2108` in the previous readable scheme.
const String mockId2108 = '4ecff4f2-b728-4d5d-b0cf-be4eb53d83e5';
/// `2109` in the previous readable scheme.
const String mockId2109 = '58fced65-a7b6-4d71-a0a4-00b148b2a4cb';
/// `2110` in the previous readable scheme.
const String mockId2110 = '401282f5-ced8-449c-86f5-0eb465c612fb';
/// `2111` in the previous readable scheme.
const String mockId2111 = '43076232-558f-4427-b03c-3a9313f983da';
/// `2112` in the previous readable scheme.
const String mockId2112 = 'eafe571a-bc81-436f-b336-f44e36b7df62';
/// `2113` in the previous readable scheme.
const String mockId2113 = 'b5aa45b1-3b0a-4b34-8d1e-e128f9f61909';
/// `2114` in the previous readable scheme.
const String mockId2114 = '7c55fcff-cca4-4b3d-b71b-9ccd1eb7d833';
/// `2115` in the previous readable scheme.
const String mockId2115 = '185caacd-6255-4df0-b253-9c07e56aebd4';
/// `2116` in the previous readable scheme.
const String mockId2116 = '411a7657-e347-4ef6-88af-95ae69bec2fe';
/// `2117` in the previous readable scheme.
const String mockId2117 = '1f9be964-b134-4544-9a50-f5deb2669c94';
/// `2118` in the previous readable scheme.
const String mockId2118 = '9e704128-39d5-4718-86f1-a5817554b6ff';
/// `2119` in the previous readable scheme.
const String mockId2119 = 'a87c524b-1017-4af2-8bd9-b4926e4137a2';
/// `2120` in the previous readable scheme.
const String mockId2120 = '543bd67b-a3f0-4654-9af5-112a1c5a0171';
/// `2121` in the previous readable scheme.
const String mockId2121 = '8824780f-4b33-4aea-bce8-9f61f52b5081';
/// `2122` in the previous readable scheme.
const String mockId2122 = '2b30d959-72eb-41b7-b655-984209ccb54c';
/// `2123` in the previous readable scheme.
const String mockId2123 = '9f95a132-0377-4328-88db-d307e7574cbf';
/// `2124` in the previous readable scheme.
const String mockId2124 = '89c30399-79c2-4654-abfe-eaa114373bce';
/// `2125` in the previous readable scheme.
const String mockId2125 = '35752cca-29f7-48b7-947e-012f133414cf';
/// `2126` in the previous readable scheme.
const String mockId2126 = '3d1713e7-d651-434d-a7ee-7fc9a7488173';
/// `2127` in the previous readable scheme.
const String mockId2127 = 'c4cf5f50-841a-487d-afd7-bfa62369cc96';
/// `2128` in the previous readable scheme.
const String mockId2128 = 'b7c6b8c8-7088-48ae-b121-57ddd11dde4a';
/// `2129` in the previous readable scheme.
const String mockId2129 = 'd3449dd1-bf72-4aab-8e68-cae216e6a86a';
/// `2130` in the previous readable scheme.
const String mockId2130 = '141d559b-f97e-4e0a-beb1-094b1642d7d1';
/// `2131` in the previous readable scheme.
const String mockId2131 = '1944a731-b001-4b10-80a8-7e34a411385b';
/// `2132` in the previous readable scheme.
const String mockId2132 = '308dd665-d095-4a3f-bcae-b9a000eb21b3';
/// `2133` in the previous readable scheme.
const String mockId2133 = '1aa07468-3b35-4c29-a42c-753bb76e0ba2';
/// `2134` in the previous readable scheme.
const String mockId2134 = '3c946391-c818-4ffe-a4d3-d52b27a1f7cd';
/// `2135` in the previous readable scheme.
const String mockId2135 = 'da40ce26-7426-4513-a6d1-c8a274d7c99e';
/// `2136` in the previous readable scheme.
const String mockId2136 = '3063f150-51fd-4459-b880-cb847f5346c9';
/// `2137` in the previous readable scheme.
const String mockId2137 = 'e9f310cd-ba96-44c7-bcce-c06b01f76013';
/// `2138` in the previous readable scheme.
const String mockId2138 = '3d9bccfb-c9be-4530-89f7-9eb778a701df';
/// `2139` in the previous readable scheme.
const String mockId2139 = 'a55249d8-7d21-4c98-a859-62175351cc81';
/// `2140` in the previous readable scheme.
const String mockId2140 = 'd649ba2d-eb31-4acd-8c32-dcab9dc16ea2';

// ------------------------------------------------------------------------
// Customer cars
// ------------------------------------------------------------------------


/// `sc-1` in the previous readable scheme.
const String mockIdSc1 = '77b8ae98-d368-4973-b932-dbbb4e053f99';
/// `sc-2` in the previous readable scheme.
const String mockIdSc2 = 'd3917472-b167-474c-a843-55e08bf1ab25';
/// `sc-3` in the previous readable scheme.
const String mockIdSc3 = 'b35da075-6fcb-4d0f-860b-ca289bdf165e';
/// `sc-4` in the previous readable scheme.
const String mockIdSc4 = '6006d934-1375-4c0d-bb39-d0d479bc3b62';
/// `sc-5` in the previous readable scheme.
const String mockIdSc5 = '1bec5aea-56ff-4cfa-a62f-55eaa5732081';
/// `sc-6` in the previous readable scheme.
const String mockIdSc6 = 'b00057af-5132-4c24-a9c9-903ab7566f79';

// ------------------------------------------------------------------------
// Quotes
// ------------------------------------------------------------------------


/// `q-2134` in the previous readable scheme.
const String mockIdQ2134 = 'd78c99e0-4140-4352-97c1-8dd089528001';
/// `q-2135` in the previous readable scheme.
const String mockIdQ2135 = '15b7c1ed-d251-4449-8e0e-63958cfa7576';
/// `q-2136` in the previous readable scheme.
const String mockIdQ2136 = '44ec4a60-6cf7-414f-a6d7-99fbc7aba25d';

// ------------------------------------------------------------------------
// Reviews
// ------------------------------------------------------------------------


/// `rev-s1` in the previous readable scheme.
const String mockIdRevS1 = 'd06b1f65-ec09-4617-87f6-0cd34fde6484';
/// `rev-s2` in the previous readable scheme.
const String mockIdRevS2 = '16e294b9-f2e4-4e38-a099-78c10d5e46e4';
/// `rev-s3` in the previous readable scheme.
const String mockIdRevS3 = '64d341f7-efe9-41c8-92a2-76dcb93ea11a';
/// `rev-s4` in the previous readable scheme.
const String mockIdRevS4 = '92cdcc11-7a30-4228-822b-ee324bd09c12';
/// `rev-s5` in the previous readable scheme.
const String mockIdRevS5 = '32498cd5-05cf-4e54-83ac-cac1662b5fe0';
/// `rev-s6` in the previous readable scheme.
const String mockIdRevS6 = 'ab35ea83-a3e4-4557-b548-61ada32a68fb';
/// `rev-s7` in the previous readable scheme.
const String mockIdRevS7 = '84aab497-b7b8-44d0-ae26-29b451dacf56';
/// `rev-s8` in the previous readable scheme.
const String mockIdRevS8 = '3c854f7c-8e12-4a73-8887-25351ab9491b';
/// `rev-s9` in the previous readable scheme.
const String mockIdRevS9 = '0c5829da-13c8-4774-86bc-83a9cf247725';
/// `rev-s10` in the previous readable scheme.
const String mockIdRevS10 = '84bca0f6-6d1a-4527-887a-fc7a01b1b114';
/// `rev-s11` in the previous readable scheme.
const String mockIdRevS11 = 'fbd87704-47e6-432b-9b27-675c02d5ad28';

// ------------------------------------------------------------------------
// Payout records
// ------------------------------------------------------------------------


/// `po-1` in the previous readable scheme.
const String mockIdPo1 = 'ad428c97-d299-4243-ada5-adb7ce7ef99f';
/// `po-2` in the previous readable scheme.
const String mockIdPo2 = '36c5f045-9e6e-4c05-9f1a-d2ce37b57d1a';
/// `po-3` in the previous readable scheme.
const String mockIdPo3 = '123d51f9-ddbd-49b7-8d75-5c69400b7bcc';
/// `po-4` in the previous readable scheme.
const String mockIdPo4 = '62b2301c-0c95-47ac-ae46-bd932a5726e6';
/// `po-5` in the previous readable scheme.
const String mockIdPo5 = '3860a9f8-3c4c-4c57-af61-56d5cf10b426';

// ------------------------------------------------------------------------
// Audit entries
// ------------------------------------------------------------------------


/// `au-1` in the previous readable scheme.
const String mockIdAu1 = '59eaba63-31ff-4885-822c-d312f8889e0b';
/// `au-2` in the previous readable scheme.
const String mockIdAu2 = '9758a075-dabe-47c1-9d3d-b0560fcf6119';
/// `au-3` in the previous readable scheme.
const String mockIdAu3 = 'e6734903-aecb-4df5-a0c2-d5dd2243fa44';
/// `au-4` in the previous readable scheme.
const String mockIdAu4 = 'e1f33668-76a7-4d9c-8f5e-ad442ebb1cb7';
/// `au-5` in the previous readable scheme.
const String mockIdAu5 = 'e41c559f-1e90-428c-907c-327b2c1997d4';
/// `au-6` in the previous readable scheme.
const String mockIdAu6 = '280ff924-9a30-4e69-bfe2-cdb262d9af76';

// ------------------------------------------------------------------------
// Workshop offers
// ------------------------------------------------------------------------


/// `of-p1-express-draft` in the previous readable scheme.
const String mockIdOfP1ExpressDraft = 'a6e8a68e-1e24-40aa-9a81-3cffd96dcb4d';
/// `of-p1-major` in the previous readable scheme.
const String mockIdOfP1Major = '2c8dba33-613e-4e9c-9a42-e9454a144a4a';
/// `of-p2-full-inflated` in the previous readable scheme.
const String mockIdOfP2FullInflated = '12a57fdd-a238-4174-a878-27e610aa8dd0';
/// `of-p3-express-unapproved` in the previous readable scheme.
const String mockIdOfP3ExpressUnapproved = '4c8987e4-3d89-4e7f-b5c0-a85c00605ec7';
/// `of-p4-tyres` in the previous readable scheme.
const String mockIdOfP4Tyres = '6e5587dc-f5e7-4517-af95-781445eed71a';
/// `of-p5-contracts-expired` in the previous readable scheme.
const String mockIdOfP5ContractsExpired = '6f9f105b-c2b0-41a8-b549-df1cb191120e';
/// `of-p6-ac` in the previous readable scheme.
const String mockIdOfP6Ac = '61f55739-706b-4772-9ada-30a52e17019e';
/// `of-p8-ev-check` in the previous readable scheme.
const String mockIdOfP8EvCheck = 'f6eb146a-3dc6-4bd4-ba54-8f0ede380b53';
/// `of-p9-detailing` in the previous readable scheme.
const String mockIdOfP9Detailing = '7671dedc-c1bf-4ba7-9405-6aafdaa0bb3b';

// ------------------------------------------------------------------------
// Promotions
// ------------------------------------------------------------------------


/// `promo-escrow` in the previous readable scheme.
const String mockIdPromoEscrow = 'bdc10a6d-d174-464a-8e02-53609dee8932';
/// `promo-p1-major` in the previous readable scheme.
const String mockIdPromoP1Major = '5e611f28-4d14-4ed1-a6ba-eeb97328fd60';
/// `promo-p2-full` in the previous readable scheme.
const String mockIdPromoP2Full = 'f6bdcb38-8355-4743-8b63-859ccf727549';
/// `promo-p4-tyres` in the previous readable scheme.
const String mockIdPromoP4Tyres = '269818a7-846b-458c-9a7e-b41c41245cf8';
/// `promo-p5-contracts` in the previous readable scheme.
const String mockIdPromoP5Contracts = 'bbfb1da9-573e-4d67-86ac-b3cd036b2748';
/// `promo-p6-ac` in the previous readable scheme.
const String mockIdPromoP6Ac = '253b45ac-ecdb-45a4-964f-6dcfb2a762a2';
/// `promo-p8-ev` in the previous readable scheme.
const String mockIdPromoP8Ev = '4aebd554-2a0e-4f19-8a8a-eb5e373fe244';
/// `promo-p9-detailing` in the previous readable scheme.
const String mockIdPromoP9Detailing = '14f58a3d-f9d2-4432-853a-c8a59f29a871';
/// `promo-pickup-platform` in the previous readable scheme.
const String mockIdPromoPickupPlatform = 'ecf295f1-d961-4ba8-ab0c-6f404c735526';

// ------------------------------------------------------------------------
// Service add-ons
// ------------------------------------------------------------------------


/// `a-ac-gas` in the previous readable scheme.
const String mockIdAAcGas = '38cea4ef-a7a2-4974-a28e-44df19ab1691';
/// `a-cabin-filter` in the previous readable scheme.
const String mockIdACabinFilter = '760035a6-1042-4b82-b11a-6fa521d0f683';
/// `a-engine-flush` in the previous readable scheme.
const String mockIdAEngineFlush = 'fe5c43ea-c16b-4107-b408-391b1efed76b';
/// `a-interior` in the previous readable scheme.
const String mockIdAInterior = '6b53d4e5-8bf8-4064-ac9d-81fb9d802415';
/// `a-oil-filter` in the previous readable scheme.
const String mockIdAOilFilter = 'baa1e4db-1877-45d0-9c38-99b803686421';
/// `a-rotation` in the previous readable scheme.
const String mockIdARotation = '666b3206-afbb-479a-bb16-8a74b7480b74';
/// `a-wipers` in the previous readable scheme.
const String mockIdAWipers = '62d6ad2a-09b8-4059-86b3-5bc56ed9fbe1';

// ------------------------------------------------------------------------
// Gallery listings
// ------------------------------------------------------------------------


/// `g1` in the previous readable scheme.
const String mockIdG1 = '92e87852-4496-47cb-a871-d5475f33d728';
/// `g2` in the previous readable scheme.
const String mockIdG2 = 'b083bfec-c74a-494d-adb7-b30a7d45e561';
/// `g3` in the previous readable scheme.
const String mockIdG3 = '5bbebc1c-d74f-4dc2-86a6-d1534f07fe70';
/// `g4` in the previous readable scheme.
const String mockIdG4 = 'a7bf1eb2-88f2-4930-885f-e9aef6d60da5';
/// `g5` in the previous readable scheme.
const String mockIdG5 = '1864c3ec-d3ca-4d9e-a2dd-b73b7ce3a978';
/// `g6` in the previous readable scheme.
const String mockIdG6 = '04338b2b-2f48-4adc-a74b-d6892c6c4509';
/// `g7` in the previous readable scheme.
const String mockIdG7 = '48f48a23-f8c5-4885-ae2c-c1cebbf5cf11';
/// `g8` in the previous readable scheme.
const String mockIdG8 = 'b06f6ab6-fc07-4671-a82f-6f94f4db44b7';
/// `g9` in the previous readable scheme.
const String mockIdG9 = 'a8bcbddf-e556-4729-9202-9ff8141ec11a';
/// `g10` in the previous readable scheme.
const String mockIdG10 = 'b5a2af4b-ea58-43ca-8869-f19f73fe614e';
/// `g11` in the previous readable scheme.
const String mockIdG11 = '0e20a024-3e24-423c-a4c7-f1e900096550';
/// `g12` in the previous readable scheme.
const String mockIdG12 = '1b02a925-f9d7-4c76-bad8-883e1cba500e';

// ------------------------------------------------------------------------
// My-ad listings
// ------------------------------------------------------------------------


/// `l1` in the previous readable scheme.
const String mockIdL1 = '5bae67ae-9b4c-4b36-8210-507f7a1ff767';
/// `l2` in the previous readable scheme.
const String mockIdL2 = '57535174-d0d3-4252-b310-b5235e18f123';
/// `l3` in the previous readable scheme.
const String mockIdL3 = 'f955bc67-c7c2-4288-98d4-036a6a51b09b';

// ------------------------------------------------------------------------
// Shop products
// ------------------------------------------------------------------------


/// `pr1` in the previous readable scheme.
const String mockIdPr1 = '4106c9bd-a5a8-47b5-bceb-509dcaf151cc';
/// `pr2` in the previous readable scheme.
const String mockIdPr2 = 'e4fb6c52-1d56-4218-bc1b-850c757a1087';
/// `pr3` in the previous readable scheme.
const String mockIdPr3 = '0d38e05e-b3e0-491c-8aad-141087cab47a';
/// `pr4` in the previous readable scheme.
const String mockIdPr4 = 'd98df099-6374-4622-a059-6d533828e222';
/// `pr5` in the previous readable scheme.
const String mockIdPr5 = 'e4213279-26cf-488b-a735-e8dfd6615cb9';
/// `pr6` in the previous readable scheme.
const String mockIdPr6 = '3192a0f6-1ad7-4b84-b010-1d3200deb11b';
/// `pr7` in the previous readable scheme.
const String mockIdPr7 = '87659992-1bfa-4ba5-8e41-14b0ce54b3bd';
/// `pr8` in the previous readable scheme.
const String mockIdPr8 = '5b2e6ca0-ae7e-4f95-a335-5139b35e8c15';
/// `pr9` in the previous readable scheme.
const String mockIdPr9 = '11dfe86d-2b93-4d71-a18d-5a8fe70da9ee';
/// `pr10` in the previous readable scheme.
const String mockIdPr10 = 'ba49702e-6442-4937-89ee-3865726b8552';
/// `pr11` in the previous readable scheme.
const String mockIdPr11 = '0293635f-2674-47dd-968e-8e16cc80e419';
/// `pr12` in the previous readable scheme.
const String mockIdPr12 = '98259488-739c-43cd-9f66-31dfc250f3a2';

// ------------------------------------------------------------------------
// Weekly challenges
// ------------------------------------------------------------------------


/// `ev-trip-charge` in the previous readable scheme.
const String mockIdEvTripCharge = '5693aa07-590a-486a-8ea8-ea98aa622235';
/// `tyre-pressure` in the previous readable scheme.
const String mockIdTyrePressure = 'ff0ce0c1-bac4-48d5-8f18-d168ce57750c';

// ------------------------------------------------------------------------
// Challenge steps
// ------------------------------------------------------------------------


/// `ev-s1` in the previous readable scheme.
const String mockIdEvS1 = 'd615ec91-a44a-40bf-920e-9363c6513250';
/// `ev-s2` in the previous readable scheme.
const String mockIdEvS2 = '18a5f2fb-c555-4ad6-a6f2-2be777031b23';
/// `ev-s3` in the previous readable scheme.
const String mockIdEvS3 = 'e2c717ca-a9b9-4859-8d2d-95244d86cfab';
/// `s1` in the previous readable scheme.
const String mockIdS1 = 'dde5e2e2-481a-4db7-9f34-9b915bf4dfbc';
/// `s2` in the previous readable scheme.
const String mockIdS2 = '9db64b00-2d85-476e-9f86-19727fc270c5';
/// `s3` in the previous readable scheme.
const String mockIdS3 = '9f798390-ab12-4894-8822-a0eed7857201';

/// Every service category, slug to GUID.
///
/// The demo catalogue is indexed by slug — `_catalogue` in
/// `mock_service_data.dart` is a slug-keyed price matrix, and reading well
/// is most of its value — so it needs one place that turns a slug into the
/// id the records actually carry. A real backend would return both fields
/// on the category and this map would go away with the rest of the mocks.
const Map<String, String> mockCategoryIdBySlug = {
  'ac': mockIdAc,
  'battery': mockIdBattery,
  'contracts': mockIdContracts,
  'detailing': mockIdDetailing,
  'diag': mockIdDiag,
  'ev-battery': mockIdEvBattery,
  'ev-charger': mockIdEvCharger,
  'ev-charging': mockIdEvCharging,
  'ev-check': mockIdEvCheck,
  'ev-sos': mockIdEvSos,
  'express': mockIdExpress,
  'full': mockIdFull,
  'major': mockIdMajor,
  'repair': mockIdRepair,
  'sos': mockIdSos,
  'tyres': mockIdTyres,
};

/// The GUID of the category with [slug]. Throws when the slug is unknown —
/// a typo'd slug in the demo catalogue is a bug in the demo catalogue, and
/// silently producing an id nothing matches would hide it behind an empty
/// screen.
String mockCategoryId(String slug) =>
    mockCategoryIdBySlug[slug] ??
    (throw ArgumentError.value(slug, 'slug', 'Unknown service category'));

/// The reverse of [mockCategoryIdBySlug].
///
/// The demo price matrix is keyed by category id, but every offering built
/// from it has to carry the category's slug too (see
/// `ServiceOffering.categorySlug`), so the lookup is needed in both
/// directions.
final Map<String, String> mockCategorySlugById = {
  for (final entry in mockCategoryIdBySlug.entries) entry.value: entry.key,
};

/// The slug of the category with [id]. Throws on an unknown id, for the same
/// reason [mockCategoryId] does.
String mockCategorySlug(String id) =>
    mockCategorySlugById[id] ??
    (throw ArgumentError.value(id, 'id', 'Unknown service category'));

/// The GUID of the demo offering sold by workshop [providerId] in category
/// [categoryId].
///
/// Offering ids are derived rather than listed — there is one per cell of the
/// price matrix in `mock_service_data.dart`, and the matrix changes far too
/// often to keep ~90 named constants beside it. This is the single definition
/// of that derivation, shared by the builder and by the tests that point at a
/// specific cell.
String mockOfferingId(String providerId, String categoryId) =>
    derivedGuid('offering', providerId, categoryId);
