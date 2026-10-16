import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/prep_section.dart';
import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';

/// A single track in My Songs.
class MySongTrack {
  final String id;
  final String title;
  final String artist;

  const MySongTrack({
    required this.id,
    required this.title,
    required this.artist,
  });
}

/// The raw playlist CSV, copied verbatim from the iOS FamilyPrep
/// `final_shazam_list` asset. Parsed at runtime with the same rules
/// (11-char video IDs, deduped, quoted titles unescaped).
const String _defaultSongsCsv = '''
sa6rZjJ43Js,The Small Faces - All Or Nothing (1966),Beat-Club
DlnE2vNqpTw,Don Williams - Tulsa time (+lyrics),RomyEnTamara
jqpAgMxhx30,Leona Lewis - Run (Official Video),leonalewis
ZPNqub966Tw,Stephanie Mabey - The Zombie Song (Lyric Video),Stephanie Mabey
cI8IO1R7Y-E,cornell campbell - sun stop shining,luke
QBPE2fZsVYU,OneRepublic - West Coast (Official Music Video),OneRepublic
unuE4W-WKeU,The Final Countdown - Vintage Reggae Café 2 - Groove Da Praia- HQ,Music Brokers
iX-QaNzd-0Y,Milky Chance - Stolen Dance (Official 4K Music Video),Milky Chance Official
u1V8YRJnr4Q,Creedence Clearwater Revival - Have You Ever Seen The Rain (Official),Creedence Clearwater Revival
CZfCtLMNQTE,Serendipity or Fate,Janice Kenney
x-qDdaplq8c,Besándote (Remastered 2001),Los Auténticos Decadentes
s37x2VSZrLw,The Weeknd & Ariana Grande – Save Your Tears (Live on The 2021 iHeart Radio Music Awards),The Weeknd
ih4zwp-0GeQ,The Honeybus - I Can't Let Maggie Go,Tinto Retto
4sXPkLfCzUQ,John Lennon - imagine - Connie Talbot with Kipper Eldridge,ConnieTalbotOfficial
3r-qDvD3F3c,There Is a Light That Never Goes Out (2011 Remaster),The Smiths - Topic
FK461PgRcPo,You Don't Have To Let Go (Album Version),Jessica Simpson
3O4J4DH4tyo,Jealous Guy (Remastered 2010),johnlennon
SzBJQnD7TRM,Stereophonics - Dakota,Stereophonics Official
WO4DMK6Qd7M,The Damned - Eloise (Single Version),TheXaviVampireskiss
xaqNFoTvRBs,This Will Make Me Happy,Studio Group - Topic
MHCPfs6EGCA,Imagine - Jack Johnson,Christian Goudy
E8b4xYbEugo,"Big Data - Dangerous (feat. Joywave)"" [Official Music Video]""",BIG DATA
l6IyI0wLegw,Erasure - Oh L'Amour (Remix) (HD) 1986,TheEsacitsuj1
217CdX7Z2tM,Fischerspooner - Emerge,Bloo Music
Hb-iP6G7IhY,It's Never Enough,Audiodub - Topic
a2c_I9ZmE4E,"Lullabye (Goodnight, My Angel) - Zoey's Extraordinary Playlist (Full Version)",Zoey's Extraordinary Playlist
mGjg_MMMhRU,Niko B - Who's That What's That,Niko B
BPX8H6tE_iA,Class Actress - Journal of Ardency,TERRIBLE RECORDS
1k8craCGpgs,Journey - Don't Stop Believin' (Official Audio),journey
gqvJd2VhqTQ,McFly - Tonight is The Night (Official Video),Official McFly
4ytX3IaFHGk,Bobby Womack - California Dreaming,A7fr3d
8VThm5QvP1M,Perfidia (Remastered),lospanchostv
6Mj776YiPCU,Paris Hilton - Stars Are Blind (Official Music Video) | Paris Hilton,Paris Hilton
Bol6PsSSgRU,정승환 (Jung Seung Hwan) - Day & Night Start Up OST Part 2 [스타트업 OST Part.2] Lyrics/가사 [Han|Rom|Eng],AlphaSubs
DQ5CINIUeSw,"LYn, HANHAE - LOVE (Are You Human OST Part.2) Easy Lyrics",Yuni da
djnWgFeGrYM,My Past,Park Se Jun - Topic
oiNkumxPVzU,RED VELVET - 'FUTURE' (미래) [Start-Up OST Part.1] Lyrics [Color Coded_Han_Rom_Eng],Zaty Farhani
bIoBFbRZUSg,She's A Star,WeAreJamesTV
6RvG5bJsu5Q,PAPER LACE - Billy Don´t Be A Hero (1974) -HQ video-,Bertierocks1
XXYlFuWEuKI,The Weeknd - Save Your Tears (Official Music Video),The Weeknd
s3XGBjcICSQ,Talking to the Moon,Bruno Mars
MMeATrAb4Xo,Love Love Letter,Park Se Jun - Topic
q-wGMlSuX_c,Lily Allen | The Fear (Official Video - Explicit Version),Lily Allen
V9NhncU5_CE,Razorlight - America (Official video),Razorlight
_Pts0jqX-yY,Supertramp - Take The Long Way Home (Official Audio),Supertramp 
OsRAFk5b8-s,Dimelo,Rak-Su
NSXQWj0HEBE,"DAVID GRAY - Say Hello, Wave Goodbye (Official Audio)",David Gray
ZFjfa_RB6Pc,The Divine Comedy - Something For The Weekend,The Divine Comedy (Official)
rhJZrRV5YKo,Bauhaus - Ziggy Stardust HD,Beggars Banquet Records
j-_1-uJ6Ml4,Leona Lewis - One More Sleep (Official Video),leonalewis
NNjrBUzXDJk,Electric Light Orchestra - Sweet Talkin' Woman (Audio),ELO
FmJ1AqtTuyo,The Toys .......A Lovers Concerto,JansLoveShack
rsExj_0IHEs,"Dave Dee,  Dozy, Beaky, Mick & Tich - The Legend Of Xanadu - HQ",HappyDuckk
d0LeL9BUPtA,Morrissey - Everyday Is Like Sunday,Morrissey
b0l3QWUXVho,NICK LOWE - CRUEL TO BE KIND - HQ Best Version. New Audio.,StiffRecordsLtd
VI53G_D5Dbw,Anything Box - Living In Oblivion (St. James Club Mix),Anything Box
s5pNyUFXt48,Depeche Mode - Just Can't Get Enough [Schizo Mix],TheJimbonjovi
P1OjD1dtNB4,No Mercy - Please Don't Go,Pop Unlimited
o2jh7N7Fldk,Irene Cara - Fame 1980 (VHS 1982 Edit),DiscoBar80
SQXqkiKXiHc,"The Paragons - The Tide Is High"" (Official Audio)""",Trojan Records Official
26PAgklYYvo,James Morrison - Broken Strings ft. Nelly Furtado,James Morrison
OqcDG_xLWPY,Edison Lighthouse "Love Grows",RealSeth
hMjwb13TFCo,I Hear You Knocking,Dave Edmunds - Topic
jSZQgIyQRhk,Sarah Brightman & Hot Gossip - I Lost My Heart To a Starship Trooper (1979),Musikladen
5fgA_yNCeq4,Clout - Substitute • TopPop,TopPop
2Evn9MiIuqM,Biffy Clyro - The Captain (Official Music Video),Biffy Clyro
w-l5FyA3pgo,KC & The Sunshine Band - Please don't go (hi quality sound),mikoozzy
MhRXOOc_p-0,Zella Day - You Sexy Thing (Official Music Video),Zella Day
5gJczNgooKY,MEGA FAZ A POSE | DJ FEDRIZZI,DJ Fedrizzi
MeMS8SuHPs0,The Marmalade - Rainbow,dergoes
GEnx9xS79Lc,Kraftwerk - The Model (official video),Oxygene 80
bYMVs-0f9PI,Time To Dance (Extended Version),THE SHOES
bLpmj059JFA,The Pretenders - I'll Stand By You,This Is Music!
aqUYPgYcgDQ,Christie - Yellow River (Official Video),ChristieVEVO
TyFAnA9oPRE,Lulu - The Man Who Sold The World (1974),MrHaggis64
qgDKtLPp46s,Flying Pickets - Only You,LotharZ
aw9mEFn38to,The Stranglers - Skin Deep,stranglersofficial
zreTvtpTeoU,Gloria Gaynor - I Am What I Am.,JOB do Brasil
m20BTdy9FGI,Olly Murs - Dear Darlin',Olly Murs
PDCeGZ3n8jY,Bizarre Love Triangle (Extended Dance Mix),New Order
b0YuQVqAArg,Seori - Wicked (Lyrics) (From Remarriage and Desires),Authentic Music
_W44NZvHc9I,Empire State of Mind (Part II) Broken Down,Alicia Keys
sa3l3Ei0tdg,Girls Talk,Dave Edmunds - Topic
kVpv8-5XWOI,"Train - Hey, Soul Sister (Official Video)",Train
kUI_P5eMVLo,Patsy Gallant - From New York To LA (Official Music Video),UnidiscMusic
JWdZEumNRmI,Air Supply - All Out Of Love (Official HD Video),Air Supply
#NAME?,Sammy Davis Jr - Mr. Bojangles (Live in Germany 1985),SammyDavisJrVEVO
wqPlb5PLBvg,The Who - You Better You Bet (Promo Video),TheWho
Oextk-If8HQ,Keane - Somewhere Only We Know (Official Music Video),Keane
Fy_jSSJOAjQ,Tom Petty & The Heartbreakers - American Girl (Live Aid 1985),Live Aid
4MyJHh451Y4,Mott The Hoople - Roll Away The Stone (1974) HD 0815007,Emma0815007
xGxhECBbw08,White Room,Cream - Band
5f13jrjaekY,Stereophonics - Hurry Up And Wait (Official Music Video),Stereophonics Official
425GpjTSlS4,The Marvelettes - Please Mr. Postman (1961),ticktock70
A0qm8nq8RcA,Linda Ronstadt - Long Long Time,santadude
zpOULjyy-n8,REO Speedwagon - Can't Fight This Feeling (Official HD Video),REO Speedwagon
JOVQ4vAmM7Y,Lulu - To Sir With Love,45RPMbyJME 
1f3o7OcYRIU,The Equals - Baby Come Back - 1968,Brian Hucek
JjqBlp6hLv4,Ninho - Carolina (Clip Officiel - REDVOLUTION),Ninho
Yf_Lwe6p-Cg,Wham! - Everything She Wants (Official Video),WHAM!
6dYWe1c3OyU,Gloria Gaynor - I Will Survive,Gloria Gaynor
bbr60I0u2Ng,The Knack - My Sharona,TheKnackVEVO
HgzGwKwLmgM,Queen - Don't Stop Me Now (Official Video Remastered 4K),Queen Official
KQetemT1sWc,The Beatles - Here Comes The Sun (2019 Mix),The Beatles
FH8Y6nN7N1E,Alison Moyet - Only You (with lyrics),inblue40
AOBs8dU4Pb8,Snow Patrol - Run (Official Video),Snow Patrol
dVNdTXEJv1A,All Saints - Pure Shores (Official Music Video),RHINO
EBt_88nxG4c,P!NK - Beautiful Trauma (Official Video),P!NK
DS_e7Yt9VMk,Amason - I Want To Know What Love Is (Official Video) -,Amason
rywUS-ohqeE,Alicia Keys - No One (Official Music Video),Alicia Keys
a_XgQhMPeEQ,Billy Joel - The Longest Time (Official HD Video),Billy Joel
zYshOUHO860,Jan Johansen....Se på mig....(1995) Swedish Music....Full Screen....,MrAydin & TIPPMUSIC
ILWSp0m9G2U,Irene Cara  - Flashdance What A Feeling (Official Music Video),UnidiscMusic
Zx4Hjq6KwO0,Keane - Everybody's Changing (Alternate Version),Keane
w3fRBzRngdc,You Ain't Seen Nothing Yet,Bachman-Turner Overdrive - Topic
tv49bC5xGVY,"Robbie Williams, Gary Barlow - Shame",Robbie Williams
fWNaR-rxAic,Carly Rae Jepsen - Call Me Maybe,Carly Rae Jepsen
XKuJUxGntRI,Amii Stewart - Knock On Wood (Official HD Video),Amii Stewart (Official)
cxY2pgQoomw,Underground Gang,Zrust dBe - Topic
J3UjJ4wKLkg,Rihanna - Take A Bow,Rihanna
B4c_SkROzzo,Matthew Wilder - Break My Stride (Audio),Matthew Wilder
LJ-VV50rBw4,Mark Wynter  -  Image Of A Girl,jim rackitts
TGwZ7MNtBFU,Gwen Stefani - Cool (Official Music Video),Gwen Stefani
Hrm95jxEFUY,I Can See Clearly Now,Sorcha Richardson
D7OVZ-CgMwM,Yazoo - Only you lyrics,Josiah McBeth
OzAWFCQGqlg,Sorcha Richardson - Ruin Your Night (Official Audio),Sorcha Richardson
zyx48F3Cf48,Labi Siffre : It Must Be Love TOTP 1971,Off The Turntable Music Archive
Dp43iM3Y5Hw,Ween - She's Your Baby,Paul
T9gMsdNQSUM,Nina Simone - Here Comes the Sun (Audio),Nina Simone
DcHKOC64KnE,Queens Of The Stone Age - Go With The Flow (Official Music Video),Queens Of The Stone Age
vRFo72wuU6w,Norman Greenbaum - Spirit In The Sky  (1970),Polydor 1000
COy_JKXtzvE,Feeder - Buck Rogers (Official HD Video),Feeder
rFP5hqVOzN8,Utah Saints - What Can You Do For Me (Original Mix),Utah Saints
#NAME?,Marianne Faithfull - As Tears Go By (Official Lyric Video),Marianne Faithfull
HTzGMEfbnAw,Juice Newton - Angel Of The Morning (Official Music Video),JuiceNewtonVEVO
w5lAY6oO8YE,First of the Gang to Die,Morrissey
h4y8WGOJu_c,Nick Drake -  Cello Song,SaturdaySonLiamStewart
mcMh6GZoFC8,A Flock Of Seagulls - Space Age Love Song 1982,Jean Rachfal
AWpsOqh8q0M,Beyoncé - If I Were A Boy,Beyoncé
wmDxJrggie8,Luther Vandross - Dance With My Father (Official Video),Luther Vandross
qbk9oVvDmXs,Cody Crump - I Guess You Get What's Coming,Cody Crump
5FcfXhhoz2c,Erasure - Chains Of Love (The Unfettered Mix),RETROREMIXES1
NTpbbQUBbuo,Hozier - Too Sweet (Official Video),Hozier
u86VdOc3asA,Keane - This Is The Last Time (Official Music Video),Keane
G7KNmW9a75Y,Miley Cyrus - Flowers (Official Video),MILEY
b00RCluE5RM,Teddy Swims - The Door (Live),Teddy Swims
SgnjwUMPCgA,Paul Carrack When You Walk In The Room,lovinthe80s1
DWoyD5gtlWs,Sha Na Na/Johnny Contardo - Those Magic Changes,faerydancer
9wxI4KK9ZYo,Lou Reed - Perfect Day (Official Audio),Lou Reed
bMCSbRLAheg,Nick Heyward - Blue Hat For A Blue Day,Nick Heyward
9xHQsMYosao,Dionne Warwick - Heartbreaker (Official Video),Dionne Warwick
_Mc_OM5oNA8,AURORA - The Seed,AURORA
BUfcT5OoP-8,Tears For Fears - Pale Shelter,Tears For Fears
tMDFv5m18Pw,Ozzy Osbourne - Crazy Train (Official Animated Video),Ozzy Osbourne
xDeX1M39JeE,Mark Ursa & Softmal - Back to Black,mark ursa
lW0G11NQJ4A,Midnight Reverie,Max Ceddo
zQOrLamT0n4,I Think I Need A New Heart - The Magnetic Fields,17caramelos
QIvzPoA-Vq0,Red Hot Chilli Pipers - Don't Stop Believing,garyplayspiano
oL4iDuzOCUM,Amy Macdonald - Don't Tell Me That It's Over (Official Video),Amy Macdonald
PSddD6w5SKc,Under the Boardwalk,The Drifters - Topic
o4qsjmLxhow,The Strokes - The Adults Are Talking (Official Audio),The Strokes
xuk1EPiMA9w,Miley Cyrus - Flowers (Lyrics),Justified Melody
8VcONCM0BzY,Righteously - Anna Ash,Anna Ash
v2Zpt-puOOg,Becky Hill - Forever Young (From The McDonald's Christmas Advert 2020),Becky Hill Official
sTxzmLyVFYY,Manfred Mann - Pretty Flamingo,ggarlick46
hN5X4kGhAtU,Empire Of The Sun - We Are The People (Official Music Video),Empire Of The Sun
tKYjUn-SBcg,Our House,"Crosby, Stills & Nash"
qUE4oDunYkc,Supergrass - Alright (Official 4K Video),Supergrass
h3JFEfdK_Ls,Billy Joel - My Life (Official Video),Billy Joel
GR3Liudev18,Chappell Roan - Pink Pony Club (Official Music Video),Chappell Roan
W0Iw57W8fFA,Freefall,Raymond Revel - Topic
erG5rgNYSdk,Weezer - Island In The Sun (Official Music Video),weezer
uZQR3KqvYPc,We've Got Tonight,Bob Seger
V9PVRfjEBTI,Billie Eilish - BIRDS OF A FEATHER (Official Music Video),Billie Eilish
2wyv52Ahry0,"Urban Cookie Collective - The Key, The Secret (Official HD Music Video)",DemonMusicGroup
mtu5XPpKLAI,Becky Hill - Only You (Official Video),Becky Hill Official
4NUfjBbyFPg,The Divine Comedy - Tonight we fly (Live),elbioubiou
nnQ2zOmb6Hg,Propaganda - Duel,PropagandaVEVO
DRpV0GePYeM,Kenny Rogers - Coward Of The County (Audio),Kenny Rogers
AJtDXIazrMo,Ellie Goulding - Love Me Like You Do (Official Video),Ellie Goulding
e80qhyovOnA,Mike Oldfield - Moonlight Shadow ft. Maggie Reilly,Mike Oldfield
0trh9Y598fM,James - Laid (Version 3),WeAreJamesTV
Pgum6OT_VH8,Muse - Starlight [Official Music Video],Muse
X_bFO1SNRZg,Ladyhawke - My Delirium (Official Video),Ladyhawke
Jt4FwLRSAdM,Charlie Landsborough - You Were Always On My Mind,ame746
Cx3QmqV2pHg,Billy Joel - She's Always a Woman (Official Audio),Billy Joel
Ou96vLl--e4,Hazel O'Connor - Will You?,Peter Dabinett
uAOR6ib95kQ,Gorillaz - DARE (Official Video),Gorillaz
GhCXAiNz9Jo,Franz Ferdinand - Take Me Out (Official Video),Domino Recording Co.
QQLWF_ItzYs,Neil Diamond - Forever in Blue Jeans (Stereo!),NeilDiamondChannel
eocCPDxKq1o,P!nk - Please Don't Leave Me (Official Video),P!NK
bo_efYhYU2A,"Lady Gaga, Bradley Cooper - Shallow (from A Star Is Born) (Official Music Video)",Lady Gaga
MGemtjVtfZM,Neil Diamond Cracklin Rosie 1970,Kathleen Mosley
usYgf8cVfvU,UB40 - One in Ten,UB40
YIHzXiM6iV8,Revolution,Jools Holland
ZCqhX89WV_0,Johnny Mathis - When a Child Is Born (from Home for Christmas),Johnny Mathis
92cwKCU8Z5c,ABBA - The Winner Takes It All,ABBA
u-pP_dCenJA,Elvis Presley - If I Can Dream ('68 Comeback Special),Elvis Presley
zzkTTA0YQe4,Bad Manners - Lorraine 1980 Video,billyidol68
DCtDAAPO-j4,DONNA SUMMER - This Time I Know It's For Real  / / HD--16:9 / /,Stavros M
IVEATF7VNTk,Leaving on a Jet Plane-PETER PAUL n MARY,Anjan Chakraborty
ZCOSPtyZAPA,The Cult - She Sells Sanctuary HD,Beggars Banquet Records
0-koDeqLulg,"Jack Savoretti feat. Sienna Miller Video Hate & Love""""",Jack Savoretti
tPgf_btTFlc,Pixies - Here Comes Your Man (Official Video),4AD
wcKsxHURj24,"Belle and Sebastian - Get Me Away from Here, I'm Dying",Jeepster Recordings
1B__8N5d_LA,Duran Duran - The Chauffeur (Official Music Video),Duran Duran
95hVxghqHPM,El Mató A Un Policía Motorizado - El Magnetismo (Official Music Video),Nacional Records
MsAAbvwsvK4,Gloria Trevi - Todos Me Miran (Videoclip Oficial),GloriaTrevi
tjpgJjdk52c,Wet Leg - Wet Dream (Official Video),Wet Leg
sMWEujABpIU,R.E.M. - Losing My Religion for cello and piano (COVER),GnuS Cello
t3ZXARu-lgw,Peligrosa,Murci Bouscayrol - Topic
riVZif0zt2Y,Willie Nelson - Bridge over troubled water,bunjcuz
3pIr6Hg02lE,Orla Gartland - 'The Power' (from the 'Trying' S5 soundtrack),Orla Gartland
LDgs7ERjC7A,Gareth Gates - Spirit In The Sky (Wiith Special Guests 'The Kumars'),GarethGatesOfficial
tbad22CKlB4,Breakin' Up Is Hard To Do - Neil Sedaka,Conkyjoe
L0QAxIKf8G4,Erma Franklin - Piece of My Heart (Official Video),ErmaFranklinVEVO
IO2HO0-kzgg,Eddie Lovette Sad Songs Say So Much,dakolohe1
rH9AriEezeI,Paul Kalkbrenner - Feed Your Head (Official Music Video),Paul Kalkbrenner
KUwjNBjqR-c,Cats In The Cradle-Harry Chapin,ETWETWFANS
jlFXhigvTvM,Jet Airliner | Steve Miller Band,drew
VU2M25clzuU,Derrick Morgan 'Moon Hop' (official audio),Trojan Records Official
uSD4vsh1zDA,The Black Eyed Peas - I Gotta Feeling (Official Music Video),Black Eyed Peas
XFkzRNyygfk,Radiohead - Creep,Radiohead
iWG6apzIWAk,Noah Kahan - Stick Season (Lyric Video),Noah Kahan
qJS3xnD7Mus,Pulp - Disco 2000,Pulp
6V2_ErOFM88,Candle in the Wind,Acker Bilk - Topic
ryH5cga0yUI,Kate Nash - Foundations,Kate Nash
Qh9-W7UKdlo,Wait And See,Stiff Little Fingers
X_03zMFBe0s,Mr Fire Coal Man,Stiff Little Fingers
wT9eQ2smjUM,The Skids - The Saints Are Coming,thecatkeaton
_6FBfAQ-NDE,Depeche Mode - Just Can't Get Enough (Official Video),Depeche Mode
dnfbMdx0PAo,Bobby Sheen - Dr. Love,brico
u4jBSc1uxx8,Nina Simone   Mr Bojangles,TheSoniaful
kUUA0Fdw_6Q,Department S - Is Vic There (Remastered),Memory Lane
CrEc81sJaDU,UB40 - Come Back Darling,UB40
UWOd1N-njlc,Erasure - It Doesn't Have To Be (Official HD Video),Erasure (Official)
9G2lqY3Nuk0,David Essex - Hold me close 1975,fritz51302
RQciegmLPAo,Squeeze - Up The Junction,Squeeze
-0WNbm1jz6A,Tubeway Army / Gary Numan -  Are 'Friends' Electric? 1979,garycee
2WN0T-Ee3q4,Limahl - Never Ending Story (Official Music Video),RHINO
8fwOC8CQwQs,The Beautiful South - I'll Sail this Ship Alone [single version],QIIQ MOODS
B4dl6JSf-bc,Commodores - Three Times A Lady [Live],TheSoulKings
lEmhfcoMiDo,5 8 6 (2015 Remaster),New Order
AQOlwMKpmvQ,Crowded House - Better Be Home Soon (Official Video),Crowded House
r3kQlzOi27M,The Go-Go's - Our Lips Are Sealed,Official GoGos
uQFjavLR52Q,David Guetta - Baby When The Light (Official Video),David Guetta
YhsTB4rq1XU,Lionel Richie - Stuck On You (Lyrics),Rewind Music Group
0M8gAhdemzY,Nick Straker Band (HD) A Walk In The Park,only1080p
MJtyWksh3K0,Marc Almond & Bronski Beat - I Feel Love,Marc Almond
cgZ-IFZFNmk,Darts - Let's Hang On,toulousedart
ZIsp_AA2ElA,Darts - Duke of Earl,Adie D
WbrSLLv0AlA,Will Young - Leave Right Now,Will Young
''';

/// Parses the songs CSV:
///   - video ID must be exactly 11 alphanumeric / `-` / `_` chars
///   - duplicate IDs are dropped
///   - uploaded CSVs must start with the columns:
///     You Tube video id, Song Title, Artist
List<MySongTrack> _parseTracks(String csv, {required bool requireHeader}) {
  final seen = <String>{};
  final tracks = <MySongTrack>[];
  final legalChars = RegExp(r'^[a-zA-Z0-9_-]+$');

  final lines = csv
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  if (lines.isEmpty) return tracks;

  var startIndex = 0;
  final firstFields = _csvFields(lines.first);
  final hasHeader = _matchesExpectedHeader(firstFields);
  if (hasHeader) {
    startIndex = 1;
  } else if (requireHeader) {
    return const [];
  }

  for (var i = startIndex; i < lines.length; i++) {
    final fields = _csvFields(lines[i]);
    if (fields.length < 3) continue;

    final rawId = fields[0].trim();
    if (rawId.length != 11 || !legalChars.hasMatch(rawId)) continue;
    if (!seen.add(rawId)) continue;

    final title = _cleanCsvField(fields[1]);
    final artist = _cleanCsvField(fields[2]);
    if (title.isEmpty) continue;

    tracks.add(MySongTrack(id: rawId, title: title, artist: artist));
  }

  return tracks;
}

bool _matchesExpectedHeader(List<String> fields) {
  if (fields.length < 3) return false;
  final normalized = fields.take(3).map(_normalizeHeader).toList();
  return normalized[0] == 'youtubevideoid' &&
      normalized[1] == 'songtitle' &&
      normalized[2] == 'artist';
}

String _normalizeHeader(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _cleanCsvField(String value) {
  var cleaned = value.trim();
  if (cleaned.length >= 2 && cleaned.startsWith('"') && cleaned.endsWith('"')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  return cleaned.replaceAll('""', '"').trim();
}

/// Simple CSV field splitter respecting double-quoted fields.
List<String> _csvFields(String line) {
  final fields = <String>[];
  var current = '';
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++;
          continue;
        }
        inQuotes = false;
        continue;
      }
      current += c;
      continue;
    }
    if (c == ',') {
      fields.add(current);
      current = '';
      continue;
    }
    if (c == '"') {
      inQuotes = true;
      continue;
    }
    current += c;
  }
  fields.add(current);
  return fields;
}

class MySongsView extends ConsumerWidget {
  const MySongsView({super.key});

  static const _config = SectionConfig(
    title: 'My Songs',
    orderIndex: 8,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIsOwner = ref.watch(isOwnerProvider);
    final isOwner = asyncIsOwner.valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Songs'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F1E8), Color(0xFFEDE6D6)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isOwner) ...[
                  const _ReadOnlyBadge(),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: ref.watch(sectionByTitleProvider(_config)).when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        data: (section) => _MySongsBody(
                          sectionId: section.id,
                          isOwner: isOwner,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  const _ReadOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          'Read-only — only the estate owner can replace this playlist.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _MySongsBody extends ConsumerStatefulWidget {
  final String sectionId;
  final bool isOwner;

  const _MySongsBody({
    required this.sectionId,
    required this.isOwner,
  });

  @override
  ConsumerState<_MySongsBody> createState() => _MySongsBodyState();
}

class _MySongsBodyState extends ConsumerState<_MySongsBody> {
  late final YoutubePlayerController _controller;
  final List<int> _playHistory = [];
  final Random _random = Random();

  List<MySongTrack> _tracks = const [];
  String _activeCsv = '';
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _shuffleOn = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final params = YoutubePlayerParams(
      showFullscreenButton: true,
      showControls: true,
      mute: false,
      playsInline: true,
      origin: 'https://www.youtube-nocookie.com',
      userAgent: isAndroid
          ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
          : null,
    );

    _controller = YoutubePlayerController(params: params);

    _controller.stream.listen((value) {
      if (!mounted || _tracks.isEmpty) return;
      setState(() {
        switch (value.playerState) {
          case PlayerState.playing:
            _isPlaying = true;
            break;
          case PlayerState.paused:
            _isPlaying = false;
            break;
          case PlayerState.ended:
            _isPlaying = false;
            _advance();
            break;
          case PlayerState.buffering:
          case PlayerState.cued:
          case PlayerState.unStarted:
          case PlayerState.unknown:
            break;
        }

        if (value.error == YoutubeError.notEmbeddable ||
            value.error == YoutubeError.sameAsNotEmbeddable ||
            value.error == YoutubeError.videoNotFound ||
            value.error == YoutubeError.cannotFindVideo) {
          _advance();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  MySongTrack get _currentTrack =>
      _tracks[_currentIndex.clamp(0, _tracks.length - 1)];

  bool get _canGoNext => _shuffleOn || _currentIndex < _tracks.length - 1;

  Future<void> _cueTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _controller.cueVideoById(videoId: _tracks[index].id);
  }

  Future<void> _syncTracksFromCsv(
    String csv, {
    required bool requireHeader,
  }) async {
    if (_activeCsv == csv) return;

    final tracks = _parseTracks(csv, requireHeader: requireHeader);
    if (tracks.isEmpty) return;

    _activeCsv = csv;
    _playHistory
      ..clear()
      ..add(0);

    if (mounted) {
      setState(() {
        _tracks = tracks;
        _currentIndex = 0;
        _isPlaying = false;
        _shuffleOn = false;
      });
    } else {
      _tracks = tracks;
      _currentIndex = 0;
      _isPlaying = false;
      _shuffleOn = false;
    }

    await _cueTrack(0);
  }

  Future<void> _pickCsv(PrepSection section) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected CSV file.')),
      );
      return;
    }

    final csv = utf8.decode(bytes, allowMalformed: true).replaceFirst(
          '\ufeff',
          '',
        );
    final tracks = _parseTracks(csv, requireHeader: true);
    if (tracks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'CSV must start with: You Tube video id, Song Title, Artist.',
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    try {
      await repo.updateSection(section.copyWith(songsCsv: csv));
      ref.invalidate(sectionProvider(widget.sectionId));
      await _syncTracksFromCsv(csv, requireHeader: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Replaced playlist with ${tracks.length} song${tracks.length == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save playlist CSV.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  /// Saves the bundled example playlist CSV so the owner can edit and re-upload it.
  Future<void> _downloadExampleCsv() async {
    try {
      final csv =
          await rootBundle.loadString('assets/data/test_video_list.csv');
      final savedPath = await FilePicker.platform.saveFile(
        fileName: 'example_playlist.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Example CSV download cancelled.'
                : 'Example CSV saved.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the example CSV.')),
      );
    }
  }

  int _randomNextIndex() {
    if (_tracks.length <= 1) return 0;
    int next;
    do {
      next = _random.nextInt(_tracks.length);
    } while (next == _currentIndex);
    return next;
  }

  void _toggleShuffle() {
    setState(() => _shuffleOn = !_shuffleOn);
  }

  void _advance() {
    if (_tracks.isEmpty) return;
    if (_shuffleOn) {
      _playIndex(_randomNextIndex());
    } else if (_currentIndex < _tracks.length - 1) {
      _playIndex(_currentIndex + 1);
    } else {
      setState(() => _isPlaying = false);
    }
  }

  void _playIndex(int index) {
    if (index < 0 || index >= _tracks.length) return;
    if (_playHistory.isEmpty || _playHistory.last != index) {
      _playHistory.add(index);
    }
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });
    _controller.loadVideoById(videoId: _tracks[index].id);
  }

  void _togglePlayPause() {
    if (_tracks.isEmpty) return;
    if (_isPlaying) {
      _controller.pauseVideo();
    } else {
      _controller.playVideo();
    }
  }

  void _previous() {
    if (_playHistory.length <= 1) return;
    _playHistory.removeLast();
    final previousIndex = _playHistory.last;
    setState(() {
      _currentIndex = previousIndex;
      _isPlaying = true;
    });
    _controller.loadVideoById(videoId: _tracks[previousIndex].id);
  }

  void _next() {
    if (_tracks.isEmpty) return;
    if (_shuffleOn) {
      _playIndex(_randomNextIndex());
    } else if (_currentIndex < _tracks.length - 1) {
      _playIndex(_currentIndex + 1);
    } else {
      _controller.pauseVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC44B8A);
    final asyncSection = ref.watch(sectionProvider(widget.sectionId));

    return asyncSection.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (section) {
        final effectiveCsv = section.songsCsv.trim().isNotEmpty
            ? section.songsCsv
            : _defaultSongsCsv;
        if (_activeCsv != effectiveCsv) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncTracksFromCsv(
              effectiveCsv,
              requireHeader: section.songsCsv.trim().isNotEmpty,
            );
          });
        }

        if (_tracks.isEmpty) {
          return const Center(child: Text('No songs available.'));
        }

        return ListView(
          children: [
            _buildHero(accent),
            const SizedBox(height: 24),
            _buildUploadCard(accent, section),
            const SizedBox(height: 24),
            _buildPlaylist(accent),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildHero(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.music_note, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'My Songs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(controller: _controller),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.play_circle_fill, color: accent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _isPlaying ? 'Now Playing' : 'Selected Track',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentIndex + 1} / ${_tracks.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currentTrack.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTrack.artist,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: _toggleShuffle,
                        tooltip: _shuffleOn ? 'Shuffle: On' : 'Shuffle: Off',
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: _shuffleOn ? accent : Colors.grey,
                          size: 26,
                        ),
                        style: _shuffleOn
                            ? IconButton.styleFrom(
                                backgroundColor: accent.withValues(alpha: 0.15),
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed:
                                _playHistory.length <= 1 ? null : _previous,
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 32,
                            color: accent,
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            onPressed: !_canGoNext ? null : _next,
                            icon: const Icon(Icons.skip_next),
                            iconSize: 32,
                            color: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard(Color accent, PrepSection section) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.upload_file, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Playlist CSV',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Choose a CSV file whose columns are: You Tube video id, Song Title, Artist.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF2C2C2E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading a file replaces the current list of tracks with the contents of that CSV.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _downloadExampleCsv,
                  icon: Icon(Icons.download_outlined, size: 18, color: accent),
                  label: Text(
                    'Example CSV file',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      decoration: TextDecoration.underline,
                      decorationColor: accent,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.songsCsv.trim().isNotEmpty
                        ? 'Using uploaded CSV'
                        : 'Using built-in starter playlist',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.isOwner && !_uploading
                      ? () => _pickCsv(section)
                      : null,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_uploading ? 'Uploading...' : 'Choose CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylist(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.list_alt, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Playlist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _tracks.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 54,
              color: Color(0x1A000000),
            ),
            itemBuilder: (context, index) {
              final track = _tracks[index];
              final isCurrent = index == _currentIndex;
              return ListTile(
                onTap: () => _playIndex(index),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? accent.withValues(alpha: 0.18)
                        : accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurrent
                        ? (_isPlaying ? Icons.volume_up : Icons.play_arrow)
                        : Icons.music_note,
                    color: accent,
                    size: 18,
                  ),
                ),
                title: Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: const Color(0xFF2C2C2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.artist.isNotEmpty
                      ? track.artist
                      : (isCurrent
                          ? (_isPlaying ? 'Playing' : 'Paused')
                          : 'Track ${index + 1}'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrent ? accent : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                tileColor: isCurrent
                    ? accent.withValues(alpha: 0.06)
                    : Colors.transparent,
              );
            },
          ),
        ),
      ],
    );
  }
}
