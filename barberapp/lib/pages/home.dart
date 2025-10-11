import 'package:barberapp/services/widget_support.dart';
import 'package:flutter/material.dart';
import 'package:barberapp/pages/detail_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff2c3925),
      body: SingleChildScrollView(
        // ✅ Added scroll
        child: Container(
          margin: const EdgeInsets.only(top: 50.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "GOOD MORNING",
                      style: TextStyle(
                        color: Color(0xfffdece7),
                        fontSize: 22.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      "ALBERT",
                      style: TextStyle(
                        color: Color(0xfffdece7),
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Color(0xfffdece7), thickness: 4.0),
                    const SizedBox(height: 10.0),
                    const Text(
                      "Fresh fades, clean cuts.\nYour style, just one tap away.",
                      style: TextStyle(
                        color: Color.fromARGB(100, 255, 255, 255),
                        fontWeight: FontWeight.w500,
                        fontSize: 18.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20.0),

              // Services
              Container(
                width: MediaQuery.of(context).size.width,
                decoration: const BoxDecoration(color: Color(0xfffdece7)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Color(0xff2c3925), thickness: 8.0),
                    const SizedBox(height: 10.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Text(
                        "Services",
                        style: AppWidget.greenTextStyle(26.0),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // ✅ Extract service item for reusability
                    serviceItem("HAIR CUT", "images/scissors.png"),
                    divider(),
                    serviceItem("SHAVING", "images/razor.png"),
                    divider(),
                    serviceItem("CREAMBATH", "images/lotion.png"),
                    divider(),
                    serviceItem("HAIR COLORING", "images/hair-color.png"),
                    divider(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget serviceItem(String title, String imagePath) {
    return GestureDetector(
      onTap: () {
        // Navigate to the detail/booking page when a service is tapped
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailPage(serviceName: title)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, bottom: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xfffdece7),
                border: Border.all(color: const Color(0xff2c3925), width: 7.0),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff2c3925),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  imagePath,
                  height: 50.0,
                  fit: BoxFit.cover,
                  color: const Color(0xfffdece7),
                ),
              ),
            ),
            const SizedBox(width: 20.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppWidget.greenTextStyle(24.0)),
                const SizedBox(height: 10.0),
                const Text(
                  "Lorem ipsum is placeholder\n text commonly used in the graphic",
                  style: TextStyle(
                    color: Color(0xff2c3925),
                    fontWeight: FontWeight.w500,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Divider(color: Color(0xff2c3925), thickness: 4.0),
    );
  }
}
