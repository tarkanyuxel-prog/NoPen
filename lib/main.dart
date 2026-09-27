import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NoPenApp());

const _green=Color(0xFF31D6A0), _ink=Color(0xFF0C1B24);
const _speech=MethodChannel('nopen/speech');
const _speechEvents=EventChannel('nopen/speech_events');

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
  @override Widget build(BuildContext c)=>Scaffold(body:IndexedStack(index:index,children:const [HomePage(),ArchivePage(),SettingsPage()]),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Ana Sayfa'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'Arşiv'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Ayarlar')]));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  Future<void> _newMeeting(BuildContext context) async {
    final controller=TextEditingController();
    final title=await showDialog<String>(
      context: context,
      builder: (dialogContext)=>AlertDialog(
        title: const Text('Yeni Toplantı'),
        content: TextField(controller:controller,autofocus:true,textCapitalization:TextCapitalization.sentences,decoration:const InputDecoration(labelText:'Toplantı adı',hintText:'Örn. Haftalık Proje Toplantısı',border:OutlineInputBorder())),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('İptal')),
          FilledButton(onPressed:(){final value=controller.text.trim();if(value.isNotEmpty)Navigator.pop(dialogContext,value);},child:const Text('Devam'))
        ],
      ),
    );
    controller.dispose();
    if(title!=null && context.mounted){
      Navigator.push(context,MaterialPageRoute(builder:(_)=>LivePage(title:title)));
    }
  }
  @override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('NoPen',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
    const SizedBox(height:6),
    Text('Toplantıyı yaz, dinlemeyi başlat.',style:TextStyle(color:Colors.grey.shade600,fontSize:16)),
    const SizedBox(height:28),
    Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const CircleAvatar(radius:26,backgroundColor:Color(0x2231D6A0),child:Icon(Icons.mic,color:_green,size:28)),
      const SizedBox(height:18),
      const Text('Yeni Toplantı',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      const Text('Toplantı adını manuel gir. NoPen sesi kaydetmeden cihaz üzerinde canlı Türkçe transkript oluşturur.'),
      const SizedBox(height:20),
      SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:()=>_newMeeting(context),icon:const Icon(Icons.add),label:const Text('Toplantı Oluştur')))
    ])),
    const SizedBox(height:18),
    const Card(child:ListTile(leading:Icon(Icons.lock_outline,color:_green),title:Text('Gizlilik'),subtitle:Text('Ses dosyası oluşturulmaz veya arşivlenmez.'))),
    const Card(child:ListTile(leading:Icon(Icons.offline_bolt_outlined,color:_green),title:Text('Cihaz İçi STT'),subtitle:Text('Desteklenen Android cihazlarda konuşma tanıma cihaz üzerinde çalışır.')))
  ]));
}

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

class SettingsPage extends StatelessWidget{const SettingsPage({super.key});@override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[const Text('Ayarlar',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:18),const ListTile(leading:Icon(Icons.mic),title:Text('Transkript'),subtitle:Text('Android cihaz içi STT • Türkçe')),const ListTile(leading:Icon(Icons.privacy_tip),title:Text('Veri ve Gizlilik'),subtitle:Text('Ses kaydı oluşturulmaz')),const ListTile(leading:Icon(Icons.info_outline),title:Text('NoPen'),subtitle:Text('v0.1.0'))]));}
