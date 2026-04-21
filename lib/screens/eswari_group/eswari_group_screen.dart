import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EswariGroupScreen extends StatefulWidget {
  const EswariGroupScreen({super.key});

  @override
  State<EswariGroupScreen> createState() => _EswariGroupScreenState();
}

class _EswariGroupScreenState extends State<EswariGroupScreen> {
  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent = Color(0xFF1976D2);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Eswari Group', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(theme, isDark),
            _buildAboutSection(theme, isDark),
            _buildCompaniesSection(theme, isDark),
            _buildServicesSection(theme, isDark),
            _buildContactSection(theme, isDark),
            _buildFooter(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [const Color(0xFF0D47A1), const Color(0xFF1565C0), const Color(0xFF1976D2)]
            : [_primary, _accent, const Color(0xFF42A5F5)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Image.asset('asserts/eswari.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 24),
          const Text(
            'Eswari Group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Building Tomorrow, Today',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('About Us', Icons.info_outline_rounded, theme, isDark),
          const SizedBox(height: 16),
          Card(
            elevation: isDark ? 4 : 2,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eswari Group is a diversified conglomerate with interests spanning technology, construction, and business solutions. With decades of experience and a commitment to excellence, we deliver innovative solutions that drive growth and success.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatCard('25+', 'Years', Icons.calendar_today_rounded, theme, isDark),
                      const SizedBox(width: 12),
                      _buildStatCard('500+', 'Projects', Icons.work_outline_rounded, theme, isDark),
                      const SizedBox(width: 12),
                      _buildStatCard('100+', 'Clients', Icons.people_outline_rounded, theme, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, ThemeData theme, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primary.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompaniesSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Our Companies', Icons.business_rounded, theme, isDark),
          const SizedBox(height: 16),
          _buildCompanyCard(
            'ASE Technologies',
            'Leading IT solutions and digital transformation services',
            Icons.computer_rounded,
            const Color(0xFF1565C0),
            [
              'Software Development',
              'Cloud Solutions',
              'Digital Marketing',
              'CRM Solutions',
            ],
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildCompanyCard(
            'Eswari Constructions',
            'Premium construction and infrastructure development',
            Icons.construction_rounded,
            const Color(0xFFE65100),
            [
              'Residential Projects',
              'Commercial Buildings',
              'Infrastructure',
              'Interior Design',
            ],
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildCompanyCard(
            'Eswari Capital',
            'Financial services and investment solutions',
            Icons.account_balance_rounded,
            const Color(0xFF2E7D32),
            [
              'Investment Advisory',
              'Financial Planning',
              'Wealth Management',
              'Business Loans',
            ],
            theme,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(
    String name,
    String description,
    IconData icon,
    Color color,
    List<String> services,
    ThemeData theme,
    bool isDark,
  ) {
    return Card(
      elevation: isDark ? 4 : 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface.withOpacity(0.5) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey[300]!),
                  ),
                  child: Text(
                    service,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Why Choose Us', Icons.star_rounded, theme, isDark),
          const SizedBox(height: 16),
          _buildFeatureCard(
            'Innovation',
            'Cutting-edge solutions powered by latest technology',
            Icons.lightbulb_outline_rounded,
            const Color(0xFFFFA726),
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Quality',
            'Uncompromising standards in every project',
            Icons.verified_outlined,
            const Color(0xFF66BB6A),
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Support',
            '24/7 customer support and assistance',
            Icons.support_agent_rounded,
            const Color(0xFF42A5F5),
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Experience',
            'Decades of industry expertise',
            Icons.workspace_premium_rounded,
            const Color(0xFFAB47BC),
            theme,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color color, ThemeData theme, bool isDark) {
    return Card(
      elevation: isDark ? 4 : 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Get In Touch', Icons.contact_mail_rounded, theme, isDark),
          const SizedBox(height: 16),
          Card(
            elevation: isDark ? 4 : 2,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildContactItem(
                    Icons.phone_rounded,
                    'Phone',
                    '+91 1234567890',
                    () => _launchURL('tel:+911234567890'),
                    theme,
                    isDark,
                  ),
                  Divider(height: 24, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
                  _buildContactItem(
                    Icons.email_rounded,
                    'Email',
                    'info@eswarigroup.com',
                    () => _launchURL('mailto:info@eswarigroup.com'),
                    theme,
                    isDark,
                  ),
                  Divider(height: 24, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
                  _buildContactItem(
                    Icons.language_rounded,
                    'Website',
                    'www.eswarigroup.com',
                    () => _launchURL('https://www.eswarigroup.com'),
                    theme,
                    isDark,
                  ),
                  Divider(height: 24, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
                  _buildContactItem(
                    Icons.location_on_rounded,
                    'Address',
                    'Bangalore, Karnataka, India',
                    null,
                    theme,
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value, VoidCallback? onTap, ThemeData theme, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D47A1),
            _primary,
            _accent,
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Image.asset('asserts/eswari.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          const Text(
            'Eswari Group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Excellence in Every Endeavor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Social Media Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(Icons.facebook_rounded, () {}),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.language_rounded, () {}),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.email_rounded, () {}),
              const SizedBox(width: 16),
              _buildSocialIcon(Icons.phone_rounded, () {}),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
          const SizedBox(height: 16),
          // Footer Links
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildFooterLink('About Us'),
              _buildFooterLink('Services'),
              _buildFooterLink('Careers'),
              _buildFooterLink('Contact'),
              _buildFooterLink('Privacy Policy'),
            ],
          ),
          const SizedBox(height: 20),
          // Copyright
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '© ${DateTime.now().year} Eswari Group. All rights reserved.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ in India',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return InkWell(
      onTap: () {},
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}
