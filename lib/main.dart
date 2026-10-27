import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const ink = Color(0xFF292B29);
const paper = Color(0xFFF7F5EF);
const accent = Color(0xFFB56B45);
const muted = Color(0xFF777970);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeskSuiteApp());
}

class DeskSuiteApp extends StatelessWidget {
  const DeskSuiteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DeskSuite',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: accent, surface: paper),
      scaffoldBackgroundColor: paper, appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink, elevation: 0)),
    home: const DeskSuiteHome(),
  );
}

class LocalStore {
  static Future<Directory> root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(base.path + '/desksuite');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
  static Future<void> write(String name, String value) async {
    final dir = await root();
    final file = File(dir.path + '/' + name);
    final temp = File(file.path + '.tmp');
    await temp.writeAsString(value, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
  static Future<String> read(String name, [String fallback = '']) async {
    final dir = await root();
    final file = File(dir.path + '/' + name);
    return await file.exists() ? file.readAsString() : fallback;
  }
  static Future<void> saveProject(Project p) async {
    final dir = Directory((await root()).path + '/projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(dir.path + '/' + p.id + '.dsproject').writeAsString(jsonEncode(p.toJson()), flush: true);
  }
  static Future<List<Project>> projects() async {
    final dir = Directory((await root()).path + '/projects');
    if (!await dir.exists()) return [];
    final result = <Project>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.dsproject')) continue;
      try { result.add(Project.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>)); } catch (_) {}
    }
    result.sort((a,b) => b.updated.compareTo(a.updated));
    return result;
  }
  static Future<String?> export(String name, Uint8List bytes) =>
      FilePicker.platform.saveFile(dialogTitle: 'Export from DeskSuite', fileName: name, bytes: bytes);
}

class Project {
  Project({String? id, this.name = 'Untitled design', this.width = 360, this.height = 480,
    List<Map<String,dynamic>>? items, DateTime? updated})
    : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(), items = items ?? [], updated = updated ?? DateTime.now();
  final String id;
  String name;
  double width, height;
  List<Map<String,dynamic>> items;
  DateTime updated;
  Map<String,dynamic> toJson() => {'schemaVersion':1,'id':id,'name':name,'width':width,'height':height,'updated':updated.toIso8601String(),'items':items};
  factory Project.fromJson(Map<String,dynamic> j) => Project(
    id:j['id'] as String?, name:j['name'] as String? ?? 'Untitled design',
    width:(j['width'] as num?)?.toDouble() ?? 360, height:(j['height'] as num?)?.toDouble() ?? 480,
    updated:DateTime.tryParse(j['updated'] as String? ?? '') ?? DateTime.now(),
    items:(j['items'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList());
  Project copy() => Project.fromJson(toJson());
}

class DeskSuiteHome extends StatefulWidget {
  const DeskSuiteHome({super.key});
  @override State<DeskSuiteHome> createState() => _DeskSuiteHomeState();
}
class _DeskSuiteHomeState extends State<DeskSuiteHome> {
  int index = 0;
  final labels = const ['Workspace','Design','Photos','Notes','Print','Business'];
  final icons = const [Icons.grid_view_rounded,Icons.draw_outlined,Icons.photo_outlined,Icons.description_outlined,Icons.print_outlined,Icons.storefront_outlined];
  void editor([Project? p]) => Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>EditorPage(project:p ?? Project())));
  @override Widget build(BuildContext context) => LayoutBuilder(builder:(context,c) {
    final wide = c.maxWidth >= 850;
    final pages = <Widget>[
      WorkspacePage(onNavigate:(i)=>setState(()=>index=i),onOpen:editor),
      CreativePage(onCreate:()=>editor(),onOpen:editor), const PhotoPage(), const NotesPage(), const PrintPage(), const BusinessPage()
    ];
    return Scaffold(
      body:SafeArea(child:Row(children:[
        if(wide) NavigationRail(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),labelType:NavigationRailLabelType.all,
          leading:const Padding(padding:EdgeInsets.all(18),child:Icon(Icons.layers_rounded,size:32,color:ink)),
          destinations:[for(var i=0;i<labels.length;i++) NavigationRailDestination(icon:Icon(icons[i]),label:Text(labels[i]))]),
        if(wide) const VerticalDivider(width:1),
        Expanded(child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(20,16,18,8),child:Row(children:[
            if(!wide) const Row(children:[Icon(Icons.layers_rounded,size:28,color:ink),SizedBox(width:8),Text('DeskSuite',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))]),
            const Spacer(),IconButton(onPressed:()=>showAboutDialog(context:context,applicationName:'DeskSuite',applicationVersion:'0.1.0'),icon:const Icon(Icons.info_outline)),
          ])),
          Expanded(child:IndexedStack(index:index,children:pages)),
        ])),
      ])),
      bottomNavigationBar:wide?null:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:[for(var i=0;i<labels.length;i++) NavigationDestination(icon:Icon(icons[i]),label:labels[i])]),
    );
  });
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key,required this.onNavigate,required this.onOpen});
  final ValueChanged<int> onNavigate; final ValueChanged<Project> onOpen;
  @override State<WorkspacePage> createState()=>_WorkspacePageState();
}
class _WorkspacePageState extends State<WorkspacePage>{
  List<Project> recent=[];
  @override void initState(){super.initState();refresh();}
  Future<void> refresh() async {final p=await LocalStore.projects();if(mounted)setState(()=>recent=p);}
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Your workspace',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,letterSpacing:-1)),
    const SizedBox(height:8),const Text('Create, refine and prepare work for print.',style:TextStyle(color:muted)),
    const SizedBox(height:22),
    Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:ink,borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF373A34),Color(0xFF222421)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('CREATE · DESIGN · PRINT · MANAGE',style:TextStyle(color:Color(0xFFD8B69C),fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1)),
      const SizedBox(height:12),const Text('From first idea\\nto finished print.',style:TextStyle(color:Colors.white,fontSize:29,height:1.12,fontWeight:FontWeight.w700)),
      const SizedBox(height:18),FilledButton(onPressed:()=>widget.onNavigate(1),child:const Text('Start a design')),
    ])),
    const SizedBox(height:26),const Text('Workspaces',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:12),
    LayoutBuilder(builder:(context,c){
      final cols=c.maxWidth>760?3:c.maxWidth>500?2:1;
      final entries=<({String title,String detail,IconData icon,int page})>[
        (title:'Creative Studio',detail:'Editable layouts and posters',icon:Icons.draw_outlined,page:1),
        (title:'Photo Studio',detail:'Rotate, resize and export',icon:Icons.photo_outlined,page:2),
        (title:'Office Notes',detail:'Write and save locally',icon:Icons.description_outlined,page:3),
        (title:'Print Studio',detail:'A4 PDF and print dialog',icon:Icons.print_outlined,page:4),
        (title:'Business & POS',detail:'Products and stock records',icon:Icons.storefront_outlined,page:5),
      ];
      return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:cols==1?3.2:1.5,children:entries.map((e)=>Card(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>widget.onNavigate(e.page),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
        Icon(e.icon,color:accent,size:28),const SizedBox(width:12),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.title,style:const TextStyle(fontWeight:FontWeight.w700)),Text(e.detail,style:const TextStyle(color:muted,fontSize:12))])),
      ]))))).toList());
    }),
    const SizedBox(height:24),const Text('Recent designs',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
    if(recent.isEmpty) const Padding(padding:EdgeInsets.all(20),child:Text('Your saved designs will appear here.',style:TextStyle(color:muted)))
    else ...recent.take(6).map((p)=>ListTile(leading:const Icon(Icons.insert_drive_file_outlined,color:accent),title:Text(p.name),subtitle:Text(p.items.length.toString()+' objects'),onTap:()=>widget.onOpen(p))),
  ]));
}

class CreativePage extends StatelessWidget {
  const CreativePage({super.key,required this.onCreate,required this.onOpen});
  final VoidCallback onCreate; final ValueChanged<Project> onOpen;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
    const Text('Creative Studio',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Create editable layouts locally and export them as PDF.',style:TextStyle(color:muted)),const SizedBox(height:22),
    Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.crop_portrait_outlined,size:36,color:accent),const SizedBox(height:12),const Text('Blank design',style:TextStyle(fontSize:21,fontWeight:FontWeight.w700)),const SizedBox(height:8),
      const Text('Add text, shapes and images. Move objects, duplicate or delete them, undo and redo changes, save the editable project, and export PDF.',style:TextStyle(color:muted,height:1.5)),
      const SizedBox(height:18),FilledButton.icon(onPressed:onCreate,icon:const Icon(Icons.add),label:const Text('Create design')),
    ]))),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:()async{
      final list=await LocalStore.projects();if(!context.mounted)return;
      await showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(ctx)=>ListView(padding:const EdgeInsets.all(20),children:[
        const Text('Saved projects',style:TextStyle(fontSize:22,fontWeight:FontWeight.w700)),
        if(list.isEmpty) const Text('No saved projects yet.'),
        ...list.map((p)=>ListTile(title:Text(p.name),subtitle:Text('Updated '+p.updated.toLocal().toString()),onTap:(){Navigator.pop(ctx);onOpen(p);})),
      ]));
    },icon:const Icon(Icons.folder_open_outlined),label:const Text('Open saved project')),
  ]);
}

class EditorPage extends StatefulWidget { const EditorPage({super.key,required this.project}); final Project project; @override State<EditorPage> createState()=>_EditorPageState(); }
class _EditorPageState extends State<EditorPage>{
  late Project p;String? selected;final undoStack=<Project>[],redoStack=<Project>[];bool busy=false;
  @override void initState(){super.initState();p=widget.project.copy();}
  void checkpoint(){undoStack.add(p.copy());if(undoStack.length>40)undoStack.removeAt(0);redoStack.clear();}
  void undo(){if(undoStack.isEmpty)return;redoStack.add(p.copy());setState(()=>p=undoStack.removeLast());}
  void redo(){if(redoStack.isEmpty)return;undoStack.add(p.copy());setState(()=>p=redoStack.removeLast());}
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> add(String kind)async{
    var text='';
    if(kind=='text'){final c=TextEditingController(text:'Your headline');final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add text'),content:TextField(controller:c,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Add'))]));if(v==null||v.isEmpty)return;text=v;}
    checkpoint();final e=<String,dynamic>{'id':DateTime.now().microsecondsSinceEpoch.toString(),'kind':kind,'text':text,'x':25.0+(p.items.length*11)%100,'y':30.0+(p.items.length*17)%180,'w':kind=='text'?250.0:110.0,'h':kind=='text'?65.0:100.0,'color':kind=='circle'?0xFFB56B45:0xFF292B29,'size':24.0};
    setState(() { p.items.add(e); selected = e['id'] as String; });
  }
  Future<void> addImage()async{
    final r=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);if(r==null||r.files.isEmpty)return;final b=r.files.single.bytes;
    if(b==null||b.length>18*1024*1024){note('Unable to read the image or it exceeds 18 MB.');return;}
    checkpoint();final e=<String,dynamic>{'id':DateTime.now().microsecondsSinceEpoch.toString(),'kind':'image','text':r.files.single.name,'x':30.0,'y':80.0,'w':230.0,'h':160.0,'color':0xFF292B29,'size':24.0,'imageData':base64Encode(b)};
    setState(() { p.items.add(e); selected = e['id'] as String; });
  }
  Future<void> save()async{setState(()=>busy=true);try{p.updated=DateTime.now();await LocalStore.saveProject(p);if(mounted)note('Project saved on this device.');}catch(e){if(mounted)note('Save failed: '+e.toString());}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> rename()async{final c=TextEditingController(text:p.name);final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Design name'),content:TextField(controller:c),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Save'))]));if(v!=null&&v.isNotEmpty)setState(()=>p.name=v);}
  pw.Widget pdfItem(Map<String,dynamic> e){final color=PdfColor.fromInt(e['color'] as int);if(e['kind']=='rect')return pw.Container(color:color);if(e['kind']=='circle')return pw.Container(decoration:pw.BoxDecoration(color:color,shape:pw.BoxShape.circle));if(e['kind']=='image'&&e['imageData']!=null){try{return pw.Image(pw.MemoryImage(base64Decode(e['imageData'] as String)),fit:pw.BoxFit.contain);}catch(_){return pw.Text('[Image unavailable]');}}return pw.Text(e['text'] as String,style:pw.TextStyle(fontSize:(e['size'] as num).toDouble()*.75,color:color,fontWeight:pw.FontWeight.bold));}
  Future<void> exportPdf({bool print=false})async{
    setState(()=>busy=true);try{
      final doc=pw.Document();doc.addPage(pw.Page(pageFormat:PdfPageFormat(p.width*.75,p.height*.75,marginAll:0),build:(_)=>pw.Container(color:PdfColors.white,child:pw.Stack(children:[
        for(final e in p.items) pw.Positioned(left:(e['x'] as num).toDouble()*.75,top:(e['y'] as num).toDouble()*.75,child:pw.SizedBox(width:(e['w'] as num).toDouble()*.75,height:(e['h'] as num).toDouble()*.75,child:pdfItem(e))),
      ]))));
      final bytes=await doc.save();if(print){await Printing.layoutPdf(onLayout:(_)async=>bytes);}else{final safe=p.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'),'_');final path=await LocalStore.export(safe+'.pdf',bytes);if(path!=null&&mounted)note('PDF exported.');}
    }catch(e){if(mounted)note('PDF export failed: '+e.toString());}finally{if(mounted)setState(()=>busy=false);}
  }
  Widget tool(IconData i,String s,VoidCallback f)=>Padding(padding:const EdgeInsets.only(right:6),child:OutlinedButton.icon(onPressed:f,icon:Icon(i,size:18),label:Text(s)));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(leading:IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back)),title:GestureDetector(onTap:rename,child:Text(p.name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700))),actions:[
    IconButton(onPressed:undoStack.isEmpty?null:undo,icon:const Icon(Icons.undo)),IconButton(onPressed:redoStack.isEmpty?null:redo,icon:const Icon(Icons.redo)),IconButton(onPressed:busy?null:save,icon:const Icon(Icons.save_outlined)),
  ]),body:Column(children:[
    SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),child:Row(children:[
      tool(Icons.title,'Text',()=>add('text')),tool(Icons.rectangle_outlined,'Shape',()=>add('rect')),tool(Icons.circle_outlined,'Circle',()=>add('circle')),tool(Icons.image_outlined,'Image',addImage),tool(Icons.picture_as_pdf_outlined,'Export PDF',()=>exportPdf()),tool(Icons.print_outlined,'Print',()=>exportPdf(print:true)),
    ])),
    Expanded(child:LayoutBuilder(builder:(context,c){
      final scale=math.min((c.maxWidth-28)/p.width,(c.maxHeight-28)/p.height).clamp(.1,2.0);
      return Center(child:Container(width:p.width*scale,height:p.height*scale,color:Colors.white,child:Stack(children:[
        for(final e in p.items)Positioned(left:(e['x'] as num).toDouble()*scale,top:(e['y'] as num).toDouble()*scale,width:(e['w'] as num).toDouble()*scale,height:(e['h'] as num).toDouble()*scale,child:GestureDetector(
          onTap:()=>setState(()=>selected=e['id'] as String),onPanStart:(_){checkpoint();setState(()=>selected=e['id'] as String);},
          onPanUpdate:(d) { setState(() { e['x'] = ((e['x'] as num).toDouble()+d.delta.dx/scale).clamp(0.0,math.max(0,p.width-(e['w'] as num).toDouble())); e['y'] = ((e['y'] as num).toDouble()+d.delta.dy/scale).clamp(0.0,math.max(0,p.height-(e['h'] as num).toDouble())); }); },
          child:Container(decoration:BoxDecoration(border:selected==e['id']?Border.all(color:accent,width:1.5):null,color:e['kind']=='rect'?Color(e['color'] as int):Colors.transparent,shape:e['kind']=='circle'?BoxShape.circle:BoxShape.rectangle),clipBehavior:Clip.hardEdge,
            child:e['kind']=='text'?Align(alignment:Alignment.topLeft,child:Text(e['text'] as String,style:TextStyle(fontSize:(e['size'] as num).toDouble()*scale,color:Color(e['color'] as int),fontWeight:FontWeight.w700))):e['kind']=='image'&&e['imageData']!=null?Image.memory(base64Decode(e['imageData'] as String),fit:BoxFit.contain):null),
        )),
      ])));
    })),
    if(selected!=null)Row(mainAxisAlignment:MainAxisAlignment.end,children:[
      TextButton.icon(onPressed:(){checkpoint();setState(()=>p.items.removeWhere((e)=>e['id']==selected));selected=null;},icon:const Icon(Icons.delete_outline),label:const Text('Delete')),
      TextButton.icon(onPressed:(){final e=p.items.where((e)=>e['id']==selected).firstOrNull;if(e==null)return;checkpoint();final cp=Map<String,dynamic>.from(e);cp['id']=DateTime.now().microsecondsSinceEpoch.toString();cp['x']=((e['x'] as num).toDouble()+16).clamp(0,p.width-(e['w'] as num).toDouble());cp['y']=((e['y'] as num).toDouble()+16).clamp(0,p.height-(e['h'] as num).toDouble());setState(() { p.items.add(cp); selected = cp['id'] as String; });},icon:const Icon(Icons.copy_outlined),label:const Text('Duplicate')),
    ]),
    if(busy)const LinearProgressIndicator(),
  ]));
}

class PhotoPage extends StatefulWidget{const PhotoPage({super.key});@override State<PhotoPage> createState()=>_PhotoPageState();}
class _PhotoPageState extends State<PhotoPage>{
  Uint8List? bytes;bool busy=false;
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> pick()async{final r=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);if(r==null||r.files.isEmpty)return;final b=r.files.single.bytes;if(b==null||b.length>30*1024*1024){note('Unable to read image or file exceeds 30 MB.');return;}setState(()=>bytes=b);}
  Future<void> process(String action)async{if(bytes==null)return;setState(()=>busy=true);try{final src=img.decodeImage(bytes!);if(src==null){note('Unsupported image format.');return;}final width=math.min(src.width,1600);final out=action=='rotate'?img.copyRotate(src,angle:90):action=='flip'?img.flipHorizontal(src):img.copyResize(src,width:width,height:(src.height*width/src.width).round());setState(()=>bytes=Uint8List.fromList(img.encodeJpg(out,quality:90)));note('Processed locally: '+out.width.toString()+' × '+out.height.toString());}catch(e){note('Image processing failed: '+e.toString());}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
    const Text('Photo Studio',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Local image processing; no upload required.',style:TextStyle(color:muted)),const SizedBox(height:20),
    Container(constraints:const BoxConstraints(minHeight:240),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:bytes==null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.add_photo_alternate_outlined,size:42,color:accent),const SizedBox(height:12),const Text('Bring in a photo',style:TextStyle(fontWeight:FontWeight.w700,fontSize:18)),const SizedBox(height:12),FilledButton.icon(onPressed:pick,icon:const Icon(Icons.upload_file),label:const Text('Choose image'))]))):Padding(padding:const EdgeInsets.all(12),child:Image.memory(bytes!,height:300,fit:BoxFit.contain))),
    if(bytes!=null)Wrap(spacing:8,runSpacing:8,children:[
      OutlinedButton.icon(onPressed:busy?null:()=>process('rotate'),icon:const Icon(Icons.rotate_right),label:const Text('Rotate 90°')),
      OutlinedButton.icon(onPressed:busy?null:()=>process('flip'),icon:const Icon(Icons.flip),label:const Text('Flip')),
      OutlinedButton.icon(onPressed:busy?null:()=>process('resize'),icon:const Icon(Icons.photo_size_select_large),label:const Text('Resize')),
      FilledButton.icon(onPressed:()async{final p=await LocalStore.export('desksuite-photo.jpg',bytes!);if(p!=null&&mounted)note('Image exported.');},icon:const Icon(Icons.save_alt),label:const Text('Export JPG')),
    ]),
    if(busy)const LinearProgressIndicator(),const SizedBox(height:14),
    const InfoNote(text:'Implemented: local import, rotate, flip, resize and JPEG export. Automatic background removal and passport-photo automation are not implemented yet.'),
  ]);
}

class NotesPage extends StatefulWidget{const NotesPage({super.key});@override State<NotesPage> createState()=>_NotesPageState();}
class _NotesPageState extends State<NotesPage>{
  final c=TextEditingController();Timer? timer;bool loaded=false,saving=false;
  @override void initState(){super.initState();LocalStore.read('notes.txt').then((v){if(mounted){c.text=v;setState(()=>loaded=true);}});c.addListener(schedule);}
  void schedule(){timer?.cancel();timer=Timer(const Duration(milliseconds:450),()async{if(!mounted)return;setState(()=>saving=true);try{await LocalStore.write('notes.txt',c.text);}finally{if(mounted)setState(()=>saving=false);}});}
  @override void dispose(){timer?.cancel();c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Office Notes',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('A simple notebook saved locally.',style:TextStyle(color:muted)),const SizedBox(height:12),
    Text(!loaded?'Loading…':saving?'Saving locally…':'Saved on this device',style:const TextStyle(color:muted,fontSize:12)),const SizedBox(height:8),
    Expanded(child:TextField(controller:c,enabled:loaded,maxLines:null,expands:true,textAlignVertical:TextAlignVertical.top,decoration:const InputDecoration(hintText:'Start writing…',contentPadding:EdgeInsets.all(16)))),
    const SizedBox(height:10),Row(children:[OutlinedButton.icon(onPressed:()async{final p=await LocalStore.export('desksuite-notes.txt',Uint8List.fromList(utf8.encode(c.text)));if(p!=null&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notes exported.')));},icon:const Icon(Icons.file_download_outlined),label:const Text('Export TXT')),const Spacer(),Text(c.text.length.toString()+' characters',style:const TextStyle(color:muted,fontSize:12))]),
  ]));
}

class PrintPage extends StatelessWidget{
  const PrintPage({super.key});
  Future<void> printTest()async{final d=pw.Document();d.addPage(pw.Page(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(42),build:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('DeskSuite Print Check',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:10),pw.Text('A4 · 210 × 297 mm'),pw.SizedBox(height:20),pw.Text('Use this sheet to check page scale and printer margins.'),pw.Spacer(),pw.Text('Generated locally by DeskSuite',style:const pw.TextStyle(fontSize:9,color:PdfColors.grey700))])));await Printing.layoutPdf(onLayout:(_)async=>d.save());}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[const Text('Print Studio',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Generate local PDFs and print through supported system services.',style:TextStyle(color:muted)),const SizedBox(height:22),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.picture_as_pdf_outlined,size:34,color:accent),const SizedBox(height:12),const Text('A4 print check',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('Create an A4 PDF and open the system print dialog.',style:TextStyle(color:muted)),const SizedBox(height:16),FilledButton.icon(onPressed:printTest,icon:const Icon(Icons.print_outlined),label:const Text('Preview / print A4'))]))),const SizedBox(height:12),const InfoNote(text:'Advanced bleed, colour management, imposition and production queues are not implemented yet.')]);
}

class BusinessPage extends StatefulWidget{const BusinessPage({super.key});@override State<BusinessPage> createState()=>_BusinessPageState();}
class _BusinessPageState extends State<BusinessPage>{
  List<Map<String,dynamic>> products=[];bool loaded=false;
  @override void initState(){super.initState();LocalStore.read('products.json','[]').then((v){try{final a=jsonDecode(v) as List;if(mounted) setState(() { products = a.map((e)=>Map<String,dynamic>.from(e as Map)).toList(); loaded = true; });}catch(_){if(mounted)setState(()=>loaded=true);}});}
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> persist()async=>LocalStore.write('products.json',jsonEncode(products));
  Future<void> addProduct()async{
    final n=TextEditingController(),price=TextEditingController(),stock=TextEditingController(text:'1');
    final v=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add product'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Product name')),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Unit price (TZS)')),TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Opening stock'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,{'name':n.text.trim(),'price':price.text,'stock':stock.text}),child:const Text('Add'))]));
    if(v==null||v['name']!.isEmpty)return;final p=double.tryParse(v['price']??'');final s=int.tryParse(v['stock']??'');if(p==null||p<0||s==null||s<0){note('Enter a valid price and stock.');return;}
    setState(()=>products.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':v['name'],'priceMinor':(p*100).round(),'stock':s,'sold':0}));await persist();
  }
  Future<void> sell(Map<String,dynamic> item)async{final i=products.indexWhere((p)=>p['id']==item['id']);if(i<0||(products[i]['stock'] as int)<1){note('No stock available.');return;}setState(() { products[i]['stock'] = (products[i]['stock'] as int)-1; products[i]['sold'] = (products[i]['sold'] as int)+1; });await persist();note('One unit recorded as sold. Payments and tax receipts are not tracked yet.');}
  @override Widget build(BuildContext context){final stockValue=products.fold<int>(0,(s,p)=>s+(p['priceMinor'] as int)*(p['stock'] as int));final sold=products.fold<int>(0,(s,p)=>s+(p['sold'] as int));return ListView(padding:const EdgeInsets.all(22),children:[
    const Text('Business & POS',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Offline product catalogue and stock tracking.',style:TextStyle(color:muted)),const SizedBox(height:18),
    Row(children:[Expanded(child:Metric(label:'Products',value:products.length.toString(),icon:Icons.inventory_2_outlined)),const SizedBox(width:10),Expanded(child:Metric(label:'Units sold',value:sold.toString(),icon:Icons.shopping_bag_outlined))]),
    const SizedBox(height:10),Metric(label:'Stock value at listed prices',value:'TZS '+(stockValue/100).toStringAsFixed(2),icon:Icons.payments_outlined),const SizedBox(height:20),
    Row(children:[const Expanded(child:Text('Product catalogue',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700))),FilledButton.icon(onPressed:addProduct,icon:const Icon(Icons.add,size:18),label:const Text('Add product'))]),
    const SizedBox(height:10),if(!loaded)const LinearProgressIndicator() else if(products.isEmpty)const EmptyState(icon:Icons.inventory_2_outlined,title:'No products yet',detail:'Add a product to start a local catalogue.') else ...products.map((p)=>Card(child:ListTile(leading:const Icon(Icons.inventory_2_outlined,color:accent),title:Text(p['name'] as String),subtitle:Text('TZS '+((p['priceMinor'] as int)/100).toStringAsFixed(2)+' · Stock: '+p['stock'].toString()),trailing:IconButton(onPressed:(p['stock'] as int)>0?()=>sell(p):null,icon:const Icon(Icons.point_of_sale_outlined))))),
    const SizedBox(height:14),const InfoNote(text:'Starter module only: payment records, refunds, suppliers, receipts, audit history and transaction-safe accounting are still to be engineered.'),
  ]);}
}
class Metric extends StatelessWidget{const Metric({super.key,required this.label,required this.value,required this.icon});final String label,value;final IconData icon;@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:accent),const SizedBox(height:10),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(label,style:const TextStyle(color:muted,fontSize:12))])));}
class InfoNote extends StatelessWidget{const InfoNote({super.key,required this.text});final String text;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF0EAE0),borderRadius:BorderRadius.circular(14)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,color:accent,size:19),const SizedBox(width:10),Expanded(child:Text(text,style:const TextStyle(color:ink,fontSize:12,height:1.5)))]));}


class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(children: [
      Icon(icon, size: 34, color: muted),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.4)),
    ]),
  );
}
