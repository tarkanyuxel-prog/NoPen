import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NoPenApp());

const _green=Color(0xFF31D6A0), _ink=Color(0xFF0C1B24);
const _speech=MethodChannel('nopen/speech');
const _speechEvents=EventChannel('nopen/speech_events');
const _clientId=String.fromEnvironment('MS_CLIENT_ID',defaultValue:'');
const _redirect=String.fromEnvironment('MS_REDIRECT_URI',defaultValue:'com.nopen.app://oauthredirect');

class Meeting {
  final String id,title,start,end,location;
  const Meeting(this.id,this.title,this.start,this.end,this.location);
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'start':start,'end':end,'location':location};
  factory Meeting.fromJson(Map<String,dynamic> j)=>Meeting(j['id']??'',j['title']??'',j['start']??'',j['end']??'',j['location']??'');
}
class Report {
  final String title,date,transcript,summary;
  final List<String> topics,decisions,actions;
  const Report({required this.title,required this.date,required this.transcript,required this.summary,required this.topics,required this.decisions,required this.actions});
  Map<String,dynamic> toJson()=>{'title':title,'date':date,'transcript':transcript,'summary':summary,'topics':topics,'decisions':decisions,'actions':actions};
  factory Report.fromJson(Map<String,dynamic> j)=>Report(title:j['title']??'',date:j['date']??'',transcript:j['transcript']??'',summary:j['summary']??'',topics:List<String>.from(j['topics']??[]),decisions:List<String>.from(j['decisions']??[]),actions:List<String>.from(j['actions']??[]));
  String asText()=>'''$title
$date

ÖZET
$summary

KONU BAŞLIKLARI
${topics.map((e)=>'• $e').join('\n')}

KARARLAR
${decisions.map((e)=>'• $e').join('\n')}

AKSİYONLAR
${actions.map((e)=>'• $e').join('\n')}

TRANSKRİPT
$transcript''';
}

class NoPenApp extends StatelessWidget {
  const NoPenApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'NoPen',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:_green,brightness:Brightness.light),scaffoldBackgroundColor:const Color(0xFFF7F9FA),fontFamily:'sans'),home:const Shell());
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState()=>_ShellState(); }
class _ShellState extends State<Shell>{
  int index=0;
  @override Widget build(BuildContext c)=>Scaffold(body:IndexedStack(index:index,children:const [CalendarPage(),ArchivePage(),SettingsPage()]),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Takvim'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'Arşiv'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Ayarlar')]));
}

class OutlookService {
  static const FlutterAppAuth auth=FlutterAppAuth();
  static String? token;
  static Future<void> signIn() async {
    if(_clientId.isEmpty) throw Exception('MS_CLIENT_ID tanımlı değil. CodeMagic environment variable ekleyin.');
    final r=await auth.authorizeAndExchangeCode(AuthorizationTokenRequest(_clientId,_redirect,discoveryUrl:'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration',scopes:const ['openid','profile','offline_access','Calendars.Read']));
    token=r?.accessToken;
    if(token==null) throw Exception('Microsoft oturumu açılamadı.');
  }
  static Future<List<Meeting>> today() async {
    if(token==null) return [];
    final now=DateTime.now(), tomorrow=DateTime(now.year,now.month,now.day+1);
    final start=DateTime(now.year,now.month,now.day).toUtc().toIso8601String();
    final end=tomorrow.toUtc().toIso8601String();
    final uri=Uri.https('graph.microsoft.com','/v1.0/me/calendarView',{'startDateTime':start,'endDateTime':end,'$orderby':'start/dateTime','$select':'id,subject,start,end,location'});
    final res=await http.get(uri,headers:{'Authorization':'Bearer $token','Prefer':'outlook.timezone="Turkey Standard Time"'});
    if(res.statusCode!=200) throw Exception('Takvim alınamadı (${res.statusCode}).');
    final data=jsonDecode(res.body) as Map<String,dynamic>;
    return (data['value'] as List).map((e){final j=e as Map<String,dynamic>;return Meeting(j['id']??'',j['subject']??'Başlıksız toplantı',j['start']?['dateTime']??'',j['end']?['dateTime']??'',j['location']?['displayName']??'');}).toList();
  }
}

class CalendarPage extends StatefulWidget { const CalendarPage({super.key}); @override State<CalendarPage> createState()=>_CalendarPageState(); }
class _CalendarPageState extends State<CalendarPage>{
  bool loading=false; String? error; List<Meeting> meetings=[];
  Future<void> connect() async {setState(()=>loading=true);try{await OutlookService.signIn();meetings=await OutlookService.today();error=null;}catch(e){error=e.toString();}if(mounted)setState(()=>loading=false);}
  @override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
    Row(children:[const Expanded(child:Text('NoPen',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800))),IconButton(onPressed:connect,icon:const Icon(Icons.sync))]),
    const SizedBox(height:18),const Text('Bugünkü Toplantılar',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:6),
    Text('Ses kaydı oluşturulmaz • Cihaz içi STT',style:TextStyle(color:Colors.grey.shade600)),const SizedBox(height:18),
    if(OutlookService.token==null) _ConnectCard(onTap:connect,loading:loading),
    if(error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(error!,style:const TextStyle(color:Colors.red))),
    ...meetings.map((m)=>_MeetingCard(m)),
    if(OutlookService.token!=null&&!loading&&meetings.isEmpty) const Padding(padding:EdgeInsets.only(top:40),child:Center(child:Text('Bugün takvimde toplantı yok.'))),
    const SizedBox(height:20),FilledButton.icon(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const LivePage(title:'Hızlı Toplantı'))),icon:const Icon(Icons.mic),label:const Text('Takvimsiz Dinlemeyi Başlat'))
  ]));
}
class _ConnectCard extends StatelessWidget{final VoidCallback onTap;final bool loading;const _ConnectCard({required this.onTap,required this.loading});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.calendar_month,size:36,color:_green),const SizedBox(height:10),const Text('Outlook Takvimini Bağla',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Text('Microsoft Graph ile yalnızca takvim okuma izni.'),const SizedBox(height:14),FilledButton(onPressed:loading?null:onTap,child:Text(loading?'Bağlanıyor…':'Microsoft ile Giriş Yap'))])));}
class _MeetingCard extends StatelessWidget{final Meeting m;const _MeetingCard(this.m);@override Widget build(BuildContext c)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(14),leading:const CircleAvatar(backgroundColor:Color(0x2231D6A0),child:Icon(Icons.groups,color:_green)),title:Text(m.title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(m.location.isEmpty?'Outlook Takvimi':m.location),trailing:IconButton(icon:const Icon(Icons.play_circle_fill,color:_green,size:34),onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>LivePage(title:m.title))))));}

class LivePage extends StatefulWidget{final String title;const LivePage({super.key,required this.title});@override State<LivePage> createState()=>_LivePageState();}
class _LivePageState extends State<LivePage>{
  StreamSubscription? sub; Timer? timer; int seconds=0; bool active=false; String transcript=''; String partial='';
  @override void initState(){super.initState();start();}
  Future<void> start() async {try{final ok=await _speech.invokeMethod<bool>('isAvailable')??false;if(!ok)throw Exception('Bu cihazda Android On-Device Speech Recognition kullanılamıyor.');sub=_speechEvents.receiveBroadcastStream().listen((e){if(!mounted)return;final m=Map<String,dynamic>.from(e as Map);setState((){final text=(m['text']??'').toString();if(m['final']==true){if(text.isNotEmpty)transcript='${transcript.isEmpty?'':'$transcript\n'}$text';partial='';}else{partial=text;}});});await _speech.invokeMethod('start',{'locale':'tr-TR'});timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});setState(()=>active=true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  Future<void> finish() async {timer?.cancel();try{await _speech.invokeMethod('stop');}catch(_){ }await sub?.cancel();if(!mounted)return;final full=[transcript,partial].where((e)=>e.trim().isNotEmpty).join('\n');final r=buildReport(widget.title,full);await saveReport(r);if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ReportPage(report:r)));}
  @override void dispose(){timer?.cancel();sub?.cancel();_speech.invokeMethod('stop');super.dispose();}
  String time(){final m=seconds~/60,s=seconds%60;return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';}
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_ink,body:SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[Text(widget.title,style:const TextStyle(color:Colors.white70,fontSize:16)),const SizedBox(height:16),const Text('Toplantı Dinleniyor',style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w800)),const Text('Ses kaydı oluşturulmadan canlı transkript',style:TextStyle(color:Colors.white60)),const Spacer(),Container(width:150,height:150,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:_green,width:3),boxShadow:const [BoxShadow(color:Color(0x5531D6A0),blurRadius:35)]),child:const Icon(Icons.mic,color:Colors.white,size:64)),const SizedBox(height:24),Text(time(),style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(active?'● Canlı dinleme aktif':'Başlatılıyor…',style:const TextStyle(color:_green)),const Spacer(),Container(width:double.infinity,height:170,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(18)),child:SingleChildScrollView(reverse:true,child:Text([transcript,partial].where((e)=>e.isNotEmpty).join('\n'),style:const TextStyle(color:Colors.white,fontSize:16,height:1.5)))),const SizedBox(height:18),SizedBox(width:double.infinity,height:54,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFFE84D5B)),onPressed:finish,icon:const Icon(Icons.stop),label:const Text('Toplantıyı Bitir')))]))));
}

Report buildReport(String title,String text){
  final lines=text.split(RegExp(r'[\n.!?]+')).map((e)=>e.trim()).where((e)=>e.length>8).toList();
  final decisions=lines.where((e)=>RegExp(r'karar|kararlaştır|olacak|yapılacak|kabul',caseSensitive:false).hasMatch(e)).take(6).toList();
  final actions=lines.where((e)=>RegExp(r'yapacak|hazırlayacak|gönderecek|takip|aksiyon|sorumlu',caseSensitive:false).hasMatch(e)).take(6).toList();
  final topics=lines.take(5).toList();
  final summary=lines.take(3).join('. ');
  return Report(title:title,date:DateTime.now().toLocal().toString().substring(0,16),transcript:text,summary:summary.isEmpty?'Transkriptte özetlenecek yeterli konuşma bulunamadı.':'$summary.',topics:topics,decisions:decisions,actions:actions);
}
Future<void> saveReport(Report r) async {final p=await SharedPreferences.getInstance();final list=p.getStringList('reports')??[];list.insert(0,jsonEncode(r.toJson()));await p.setStringList('reports',list);}

class ReportPage extends StatelessWidget{final Report report;const ReportPage({super.key,required this.report});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Toplantı Raporu')),body:ListView(padding:const EdgeInsets.all(18),children:[Text(report.title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),Text(report.date),const SizedBox(height:14),_Section('Özet',[report.summary],Icons.summarize),_Section('Konu Başlıkları',report.topics,Icons.topic),_Section('Kararlar',report.decisions,Icons.check_circle),_Section('Aksiyonlar',report.actions,Icons.bolt),const SizedBox(height:10),FilledButton.icon(onPressed:()=>Share.share(report.asText(),subject:report.title),icon:const Icon(Icons.share),label:const Text('Telefonun Paylaş Menüsünü Aç'))]));}
class _Section extends StatelessWidget{final String title;final List<String> items;final IconData icon;const _Section(this.title,this.items,this.icon);@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:_green),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))]),const SizedBox(height:8),if(items.isEmpty)const Text('Bulunamadı') else ...items.map((e)=>Padding(padding:const EdgeInsets.only(bottom:6),child:Text('• $e')))])));}

class ArchivePage extends StatefulWidget{const ArchivePage({super.key});@override State<ArchivePage> createState()=>_ArchivePageState();}
class _ArchivePageState extends State<ArchivePage>{List<Report> reports=[];String q='';@override void initState(){super.initState();load();}Future<void> load()async{final p=await SharedPreferences.getInstance();reports=(p.getStringList('reports')??[]).map((e)=>Report.fromJson(jsonDecode(e))).toList();if(mounted)setState((){});}@override Widget build(BuildContext c){final shown=reports.where((r)=>r.title.toLowerCase().contains(q.toLowerCase())||r.transcript.toLowerCase().contains(q.toLowerCase())).toList();return SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[const Text('Arşiv',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:14),TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Toplantılarda ara…',border:OutlineInputBorder())),const SizedBox(height:14),if(shown.isEmpty)const Padding(padding:EdgeInsets.only(top:50),child:Center(child:Text('Henüz arşivlenmiş toplantı yok.'))) else ...shown.map((r)=>Card(child:ListTile(title:Text(r.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(r.date),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ReportPage(report:r))))))]));}}

class SettingsPage extends StatelessWidget{const SettingsPage({super.key});@override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[const Text('Ayarlar',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:18),const ListTile(leading:Icon(Icons.mic),title:Text('Transkript'),subtitle:Text('Android cihaz içi STT • Türkçe')),const ListTile(leading:Icon(Icons.privacy_tip),title:Text('Veri ve Gizlilik'),subtitle:Text('Ses kaydı oluşturulmaz')),ListTile(leading:const Icon(Icons.calendar_month),title:const Text('Outlook Takvimi'),subtitle:Text(_clientId.isEmpty?'Kurulum gerekli':'Microsoft Graph yapılandırıldı')),const ListTile(leading:Icon(Icons.info_outline),title:Text('NoPen'),subtitle:Text('v0.1.0'))]));}
