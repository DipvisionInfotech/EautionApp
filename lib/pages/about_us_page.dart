import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile ? _buildDrawer(context) : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Header(
              activePage: 'About Us',
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () {},
              onAuctionTap: () => Navigator.pushNamed(context, '/auction'),
              onClassifiedTap: () => Navigator.pushNamed(context, '/classified'),
              onContactUsTap: () => Navigator.pushNamed(context, '/contact-us'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 1200 ? screenWidth * 0.1 : 20,
                vertical: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About Us',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (screenWidth > 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildImage()),
                        const SizedBox(width: 40),
                        Expanded(child: _buildAboutText()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildImage(),
                        const SizedBox(height: 30),
                        _buildAboutText(),
                      ],
                    ),
                  const SizedBox(height: 40),
                  _buildExtendedText(),
                ],
              ),
            ),
            Footer(
              onHomeTap: () => Navigator.pushReplacementNamed(context, '/'),
              onAboutUsTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1000&q=80',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildAboutText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The term Salvaging invokes a mixed reaction amongst all, especially with professionals connected to the General Insurance sector or Industrialists who deal with selling of waste or scrap items. We understand that in the general Insurance Sector, Salvaging is the last step of the pyramid and basically acts as the foundation towards effective loss minimisation and loss of public money.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        SizedBox(height: 20),
        Text(
          'We provide an online marketplace to sell the salvage under Insurance Claims or reputed clients through forward e-Auction.',
          style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        Text(
          'We at Seal The Deal are a group of professionals from different sectors (including Salvaging, Marketing, Sales, Human Resource) with minimum 5-7 years of experience who have envisaged and have come together to improve and improvise the process of salvaging.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildExtendedText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our operations team is the heart of the company who have at least 5-7 years’ experience in devising the terms and conditions of the e-Auction and take care of all the documentation part. We, at Seal The Deal understand that the terms and conditions of the e-Auction is the most important part of salvaging and it is made stringently such that there are minimal deviations.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        SizedBox(height: 20),
        Text(
          'The art of salvaging requires an in-depth knowledge of the material to be salvaged and the prospective rate at which the subject material can be sold. Our team has professionals who have thorough knowledge of the materials and their current market rates.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        SizedBox(height: 20),
        Text(
          'The portfolio of our marketing team is not only to invite salvage buyers already registered with us but also find new potential buyers from the internet and adding them up as well as educating them to participate in the e-Auctions. Transparency is the most important word in salvaging. To realise the highest possible value of damaged, dead, obsolete and unwanted assets, the key is a competitive approach with the participation of maximum participants in a forward e-Auction. Our marketing team continuously thrives for the same and are always on the lookout for end users thus increasing the value of the salvage.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        SizedBox(height: 20),
        Text(
          'Last but not the least, we have a dedicated team of professionals who supervise the lifting work (wherever necessary) such that all issues related to lifting are minimised and the lifting process is streamlined.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        SizedBox(height: 20),
        Text(
          'We may be the latest player in the e-Auction service sector, however with the kind of diverse experience that our team has from different sectors, we are sure to make the difference and provide the best possible service in the sector and change the face of Salvaging.',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1A237E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Seal The Deal', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Streamlining Salvage', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Us'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('Auction'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/auction');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Classified'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/classified');
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/contact-us');
            },
          ),
        ],
      ),
    );
  }
}
