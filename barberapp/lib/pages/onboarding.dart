import 'package:barberapp/services/widget_support.dart';
import 'package:flutter/material.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(child: Column(children: [
        Image.asset("images/barber.png"),
        Container(
          padding: EdgeInsets.only(left: 20.0, right: 40.0),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(color: Color(0xff2c3925),),child: Column(children: [
            SizedBox(height: 30.0,),
            Text("BarberApp",textAlign: TextAlign.center ,style: TextStyle(color: const Color.fromARGB(180, 255, 255, 255), fontWeight: FontWeight.w500, fontSize: 18.0),),
            SizedBox(height: 50.0,),
            Material(
              elevation: 5.0,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 70,
                width: 280,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Color(0xfffdece7),borderRadius: BorderRadius.circular(10)),child: Center(child: Text("BOOK NOW", style: AppWidget.healineTextStyle(24.0),))),
            ),
        ],),
        )
      ],),),
    );
  }
}
