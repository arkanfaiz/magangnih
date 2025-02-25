import 'package:flutter/material.dart';
import 'videoplayerwidget.dart';

class Cctv extends StatelessWidget {
  const Cctv({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard CCTV",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 33, 122, 185),
        foregroundColor: Colors.white,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth < 600 ? 1 : 2;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    crossAxisCount, // One row on small screens, two on larger
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 16 / 9,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Camera ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: VideoPlayerWidget(
                            videoUrl:
                                'https://cdn.discordapp.com/attachments/1236343301620367380/1337681732740190218/lv_0_20250207234103.mp4?ex=67b38972&is=67b237f2&hm=5773a238e5c961f1c76a0a156e037dd21d844b1a729587c0a8766247571c28e2&',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: Cctv(),
  ));
}
