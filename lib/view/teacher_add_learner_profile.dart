import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class TeacherAddLearnerProfilePage extends StatefulWidget {
  final String role;
  final int userId;
  final int classId;
  final int? learnerId;

  const TeacherAddLearnerProfilePage({
    Key? key,
    required this.role,
    required this.userId,
    required this.classId,
    this.learnerId,
  }) : super(key: key);

  @override
  State<TeacherAddLearnerProfilePage> createState() =>
      _TeacherAddLearnerProfilePageState();
}

class _TeacherAddLearnerProfilePageState
    extends State<TeacherAddLearnerProfilePage> {

  final _formKey = GlobalKey<FormState>();

  final surnameController = TextEditingController();
  final givenNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lrnController = TextEditingController();
  final birthdayController = TextEditingController();

  final provinceController = TextEditingController();
  final cityController = TextEditingController();
  final barangayController = TextEditingController();

  final parentNameController = TextEditingController();
  final parentOccupationController = TextEditingController();
  final ageMotherController = TextEditingController();
  final spouseOccupationController = TextEditingController();

  DateTime? selectedBirthDate;
  String? selectedSex;
  String? selectedBirthOrder;
  String? selectedSiblings;
  String? selectedHandedness;

  bool _loading = false;

  static const sexOptions = ["Male","Female"];
  static const birthOrderOptions = ["1st","2nd","3rd","4th","5th","6th+"];
  static const siblingOptions = ["0","1","2","3","4","5","6+"];
  static const handednessOptions = [
    "Right-handed","Left-handed","Ambidextrous","None yet"
  ];

  @override
  void initState() {
    super.initState();
    if(widget.learnerId != null) _loadLearnerForEdit();
  }


  Future<void> _loadLearnerForEdit() async {
    setState(()=>_loading=true);
    final db = await DatabaseService.instance.getDatabase();

    final rows = await db.query(
      DatabaseService.learnerTable,
      where: 'learner_id=?',
      whereArgs: [widget.learnerId],
      limit: 1,
    );

    if(rows.isNotEmpty){
      final l = rows.first;

      surnameController.text = l['surname'].toString();
      givenNameController.text = l['given_name'].toString();
      middleNameController.text = l['middle_name'].toString();
      lrnController.text = l['lrn'].toString();

      selectedSex = l['sex'] as String?;
      selectedHandedness = l['handedness'] as String?;
      selectedBirthOrder = l['birth_order'] as String?;
      selectedSiblings = l['number_of_siblings']?.toString();

      provinceController.text = l['province'].toString();
      cityController.text = l['city'].toString();
      barangayController.text = l['barangay'].toString();
      parentNameController.text = l['parent_name'].toString();
      parentOccupationController.text = l['parent_occupation'].toString();
      spouseOccupationController.text = l['spouse_occupation'].toString();
      ageMotherController.text = l['age_mother_at_birth'].toString();

      final bday = l['birthday']?.toString();
      if(bday != null){
        final dt = DateTime.tryParse(bday);
        if(dt != null){
          selectedBirthDate = dt;
          birthdayController.text="${dt.month}/${dt.day}/${dt.year}";
        }
      }
    }

    setState(()=>_loading=false);
  }


  Future<void> _saveLearner() async {
    if(!_formKey.currentState!.validate()) return;

    setState(()=>_loading=true);

    try{
      final db = await DatabaseService.instance.getDatabase();

      final data = {
        "class_id": widget.classId,
        "surname": surnameController.text.trim(),
        "given_name": givenNameController.text.trim(),
        "middle_name": middleNameController.text.trim(),
        "sex": selectedSex,
        "lrn": int.tryParse(lrnController.text.trim()),
        "birthday": selectedBirthDate?.toIso8601String(),
        "handedness": selectedHandedness,
        "birth_order": selectedBirthOrder,
        "barangay": barangayController.text.trim(),
        "city": cityController.text.trim(),
        "province": provinceController.text.trim(),
        "parent_name": parentNameController.text.trim(),
        "parent_occupation": parentOccupationController.text.trim(),
        "age_mother_at_birth": int.tryParse(ageMotherController.text.trim()),
        "spouse_occupation": spouseOccupationController.text.trim(),
        "number_of_siblings": int.tryParse(selectedSiblings ?? "0"),
        "status": DatabaseService.statusActive,
      };

      if(widget.learnerId == null){
        await db.insert(DatabaseService.learnerTable, data);
      }else{
        await db.update(
          DatabaseService.learnerTable,
          data,
          where: "learner_id=?",
          whereArgs: [widget.learnerId],
        );
      }

      if(!mounted) return;
      Navigator.pop(context,true);

    }catch(e){
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save error: $e")));
    }finally{
      if(mounted) setState(()=>_loading=false);
    }
  }

  // ================= UI (UNCHANGED) =================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile
          ? Navbar(selectedIndex:1,onItemSelected:(_){},role:widget.role,userId:widget.userId)
          : null,
      appBar: isMobile
          ? AppBar(title: Text(widget.learnerId==null?"Add Learner Profile":"Edit Learner Profile"),backgroundColor: const Color(0xFFE64843))
          : null,
      body: Stack(children:[
        SafeArea(child:Row(children:[
          if(!isMobile) Navbar(selectedIndex:1,onItemSelected:(_){},role:widget.role,userId:widget.userId),
          Expanded(child:Column(children:[
            if(!isMobile) _desktopHeader(),
            Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_desktopFormWrapper()),
          ])),
        ])),
        if(!isMobile) Positioned(top:MediaQuery.of(context).padding.top+10,left:285,child:const NavbarBackButton()),
      ]),
    );
  }

  Widget _desktopHeader()=>Container(
    color: const Color(0xFFF7F4F6),
    padding: const EdgeInsets.fromLTRB(80,14,16,10),
    child: Text(widget.learnerId==null?"Add Learner Profile":"Edit Learner Profile",
        style: const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
  );

  Widget _desktopFormWrapper()=>SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Center(child:SizedBox(width:720,child:_form())),
  );

  Widget _form()=>Form(
    key:_formKey,
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text("Student Information",style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:8),
      _field("Surname*",surnameController),
      _field("First Name*",givenNameController),
      _field("Middle Name*",middleNameController),
      _dropdown("Sex*",sexOptions,selectedSex,(v)=>setState(()=>selectedSex=v)),
      _dateField(),
      _field("LRN (12 digits)*",lrnController),
      _dropdown("Handedness*",handednessOptions,selectedHandedness,(v)=>setState(()=>selectedHandedness=v)),
      _dropdown("Birth Order*",birthOrderOptions,selectedBirthOrder,(v)=>setState(()=>selectedBirthOrder=v)),
      _dropdown("Number of Siblings*",siblingOptions,selectedSiblings,(v)=>setState(()=>selectedSiblings=v)),
      const SizedBox(height:16),
      const Text("Address Information",style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:8),
      _field("Province*",provinceController),
      _field("City*",cityController),
      _field("Barangay*",barangayController),
      const SizedBox(height:16),
      const Text("Parent / Guardian Information",style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:8),
      _field("Parent Name*",parentNameController),
      _field("Parent Occupation*",parentOccupationController),
      _field("Mother's Age at Birth*",ageMotherController),
      _field("Spouse Occupation*",spouseOccupationController),
      const SizedBox(height:24),
      SizedBox(
        width:double.infinity,
        height:46,
        child:ElevatedButton(
          style:ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A1E22),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(4)),
          ),
          onPressed:_saveLearner,
          child:Text(widget.learnerId==null?"Save Learner":"Save Changes",
              style: const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _field(String label,TextEditingController c)=>Padding(
    padding: const EdgeInsets.only(bottom:12),
    child:TextFormField(
      controller:c,
      validator:(v)=>v==null||v.trim().isEmpty?"Required":null,
      decoration:InputDecoration(
        labelText:label,filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(6)),
      ),
    ),
  );

  Widget _dropdown(String label,List<String> items,String? value,Function(String?) onChanged)
  =>Padding(
    padding: const EdgeInsets.only(bottom:12),
    child:DropdownButtonFormField<String>(
      value:value,
      items:items.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
      onChanged:onChanged,
      validator:(v)=>v==null?"Required":null,
      decoration:InputDecoration(
        labelText:label,filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(6)),
      ),
    ),
  );

  Widget _dateField()=>Padding(
    padding: const EdgeInsets.only(bottom:12),
    child:TextFormField(
      readOnly:true,
      validator:(_)=>selectedBirthDate==null?"Required":null,
      controller:birthdayController,
      onTap:() async {
        final picked = await showDatePicker(
          context: context,
          initialDate:selectedBirthDate??DateTime(2020),
          firstDate:DateTime(2000),
          lastDate:DateTime.now(),
        );
        if(picked!=null){
          setState(() {
            selectedBirthDate=picked;
            birthdayController.text="${picked.month}/${picked.day}/${picked.year}";
          });
        }
      },
      decoration:InputDecoration(
        labelText:"Date of Birth*",filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(6)),
      ),
    ),
  );
}