import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  final Map<String, dynamic> personalDetail;
  final Map<String, dynamic> familyDetail;
  final Map<String, dynamic> lifestyle;
  final Map<String, dynamic> partner;
  final String id ;

  const ProfileTabs({
    Key? key,
    required this.personalDetail,
    required this.familyDetail,
    required this.lifestyle,
    required this.partner,
    required this.id,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return
      DefaultTabController(


      length: 1,
      child: Container(

        constraints: BoxConstraints(
          minHeight: 400, // Set a minimum height
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Or use a fixed max height
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.red : Colors.red,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? [] : [

          ],
        ),
        child: Column(
          children: [
            // Modern Tab Bar with gradient - FIXED: Removed Expanded from this part


            // Tab Content - FIXED: Use Flexible instead of Expanded
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: TabBarView(
                  children: [
                    _buildPersonalDetails(isDark),



                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildPartnerPreferences(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Basic Preferences
              _buildSectionCard(
                title: 'Basic Preferences',
                icon: Icons.filter_list_outlined,
                color: isDark ? Colors.red : Colors.red,
                iconColor: Colors.red,
                isDark: isDark,
                children:
                [
                  if (partner['minage'] != null && partner['maxage'] != null)
                    _buildInfoItem(
                      label: 'Age Range',
                      value: '${partner['minage']} - ${partner['maxage']} years',
                      icon: Icons.cake_outlined,
                      isDark: isDark,
                    ),
                  if (partner['minheight'] != null && partner['maxheight'] != null)
                    _buildInfoItem(
                      label: 'Height Range',
                      value: '${partner['minheight']} - ${partner['maxheight']} cm',
                      icon: Icons.height_outlined,
                      isDark: isDark,
                    ),
                  if (partner['minweight'] != null && partner['maxweight'] != null)
                    _buildInfoItem(
                      label: 'Weight Range',
                      value: '${partner['minweight']} - ${partner['maxweight']} kg',
                      icon: Icons.monitor_weight_outlined,
                      isDark: isDark,
                    ),
                  if ((partner['maritalstatus'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Marital Status',
                      value: partner['maritalstatus'].toString(),
                      icon: Icons.favorite_border_outlined,
                      isDark: isDark,
                    ),
                  if ((partner['profilewithchild'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Profile with Child',
                      value: partner['profilewithchild'].toString(),
                      icon: Icons.child_friendly_outlined,
                      isDark: isDark,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Religious Preferences
              if (((partner['religion'] as String?)?.isNotEmpty == true) ||
                  ((partner['caste'] as String?)?.isNotEmpty == true) ||
                  ((partner['community'] as String?)?.isNotEmpty == true) ||
                  ((partner['mothertoungue'] as String?)?.isNotEmpty == true) ||
                  ((partner['herscopeblief'] as String?)?.isNotEmpty == true) ||
                  ((partner['manglik'] as String?)?.isNotEmpty == true))
                _buildSectionCard(
                  title: 'Religious Preferences',
                  icon: Icons.temple_hindu_outlined,
                  color: isDark ? Colors.orange : Colors.orange,
                  iconColor: Colors.orange,
                  isDark: isDark,
                  children:
                  [
                    if ((partner['religion'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Religion',
                        value: partner['religion'].toString(),
                        icon: Icons.mosque_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['caste'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Caste',
                        value: partner['caste'].toString(),
                        icon: Icons.groups_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['community'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Community',
                        value: partner['community'].toString(),
                        icon: Icons.groups_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['mothertoungue'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Mother Tongue',
                        value: partner['mothertoungue'].toString(),
                        icon: Icons.language_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['herscopeblief'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Horoscope Belief',
                        value: partner['herscopeblief'].toString(),
                        icon: Icons.psychology_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['manglik'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Manglik',
                        value: partner['manglik'].toString(),
                        icon: Icons.spa_outlined,
                        isDark: isDark,
                      ),
                  ],
                ),

              if (((partner['religion'] as String?)?.isNotEmpty == true) ||
                  ((partner['caste'] as String?)?.isNotEmpty == true) ||
                  ((partner['community'] as String?)?.isNotEmpty == true) ||
                  ((partner['mothertoungue'] as String?)?.isNotEmpty == true) ||
                  ((partner['herscopeblief'] as String?)?.isNotEmpty == true) ||
                  ((partner['manglik'] as String?)?.isNotEmpty == true))
                const SizedBox(height: 16),

              // Location Preferences
              if (((partner['country'] as String?)?.isNotEmpty == true) ||
                  ((partner['state'] as String?)?.isNotEmpty == true) ||
                  ((partner['district'] as String?)?.isNotEmpty == true) ||
                  ((partner['city'] as String?)?.isNotEmpty == true))
                _buildSectionCard(
                  title: 'Location Preferences',
                  icon: Icons.location_on_outlined,
                  color: isDark ? Colors.blue : Colors.blue,
                  iconColor: Colors.blue,
                  isDark: isDark,
                  children:
                  [
                    if ((partner['country'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Country',
                        value: partner['country'].toString(),
                        icon: Icons.public_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['state'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'State',
                        value: partner['state'].toString(),
                        icon: Icons.map_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['district'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'District',
                        value: partner['district'].toString(),
                        icon: Icons.location_city_outlined,
                        isDark: isDark,
                      ),
                    if ((partner['city'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'City',
                        value: partner['city'].toString(),
                        icon: Icons.location_city_outlined,
                        isDark: isDark,
                      ),
                  ],
                ),

              if (((partner['country'] as String?)?.isNotEmpty == true) ||
                  ((partner['state'] as String?)?.isNotEmpty == true) ||
                  ((partner['district'] as String?)?.isNotEmpty == true) ||
                  ((partner['city'] as String?)?.isNotEmpty == true))
                const SizedBox(height: 16),

              // Other Sections...
              // Note: I've condensed for brevity, but you would continue the pattern
              // Add Education & Career, Lifestyle Preferences, Physical Preferences sections

              // Other Expectations
              if ((partner['otherexpectation'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildTextCard(
                  title: 'Other Expectations',
                  content: partner['otherexpectation'].toString(),
                  icon: Icons.star_outline,
                  color: isDark ? Colors.red : Colors.red,
                  iconColor: Colors.red,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.3 : 1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required bool isDark,
  }) {
    final trimmedContent = content.trim();
    return trimmedContent.isNotEmpty ? Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.3 : 1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : color.withOpacity(0.3),
                ),
              ),
              child: Text(
                trimmedContent,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[200] : Colors.grey[800],
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    ) : const SizedBox.shrink();
  }


  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    final valueStr = value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valueStr.isEmpty ? 'Not specified' : valueStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Alternative: Use a fixed height approach if Flexible doesn't work

  Widget _buildPersonalDetails(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Profile Summary Card
            //  _buildProfileSummaryCard(isDark),
              const SizedBox(height: 16),

              // Basic Information
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.info_outline_rounded,
                color: isDark ? Colors.blue : Colors.red,
                iconColor: Colors.blue,
                isDark: isDark,
                children: [
                  _buildInfoItem(
                    label: 'Name',
                    value: 'MS:${id ?? ''} ${personalDetail['lastName'] ?? ''}'.trim(),
                    icon: Icons.person_outline,
                    isDark: isDark,
                  ),
                  _buildInfoItem(
                    label: 'Member ID',
                    value: "MS:${id}",
                    icon: Icons.badge_outlined,
                    isDark: isDark,
                  ),

                  if ((personalDetail['birthtime'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Birth Time',
                      value: personalDetail['birthtime'].toString(),
                      icon: Icons.access_time_filled_outlined,
                      isDark: isDark,
                    ),
                  if ((personalDetail['birthcity'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Birth City',
                      value: personalDetail['birthcity'].toString(),
                      icon: Icons.location_city_outlined,
                      isDark: isDark,
                    ),
                  if ((personalDetail['height_name'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Height',
                      value: personalDetail['height_name'].toString(),
                      icon: Icons.height_outlined,
                      isDark: isDark,
                    ),
                  if ((personalDetail['maritalStatusName'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Marital Status',
                      value: personalDetail['maritalStatusName'].toString(),
                      icon: Icons.favorite_border_outlined,
                      isDark: isDark,
                    ),
                  if ((personalDetail['bloodGroup'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Blood Group',
                      value: personalDetail['bloodGroup'].toString(),
                      icon: Icons.bloodtype_outlined,
                      isDark: isDark,
                    ),
                  _buildInfoItem(
                    label: 'Disability',
                    value: (personalDetail['Disability'] as String?) ?? 'None',
                    icon: Icons.accessible_outlined,
                    isDark: isDark,
                  ),
                  if ((personalDetail['manglik'] as String?)?.isNotEmpty == true)
                    _buildInfoItem(
                      label: 'Manglik',
                      value: personalDetail['manglik'].toString(),
                      icon: Icons.spa_outlined,
                      isDark: isDark,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Religious Information
              if (((personalDetail['religionName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['communityName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['subCommunityName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['motherTongue'] as String?)?.isNotEmpty == true))
                _buildSectionCard(
                  title: 'Religious Information',
                  icon: Icons.temple_hindu_outlined,
                  color: isDark ? Colors.orange: Colors.orange,
                  iconColor: Colors.orange,
                  isDark: isDark,
                  children: [
                    if ((personalDetail['religionName'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Religion',
                        value: personalDetail['religionName'].toString(),
                        icon: Icons.mosque_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['communityName'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Community',
                        value: personalDetail['communityName'].toString(),
                        icon: Icons.groups_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['subCommunityName'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Sub-Community',
                        value: personalDetail['subCommunityName'].toString(),
                        icon: Icons.group_work_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['motherTongue'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Mother Tongue',
                        value: personalDetail['motherTongue'].toString(),
                        icon: Icons.language_outlined,
                        isDark: isDark,
                      ),
                  ],
                ),

              if (((personalDetail['religionName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['communityName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['subCommunityName'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['motherTongue'] as String?)?.isNotEmpty == true))
                const SizedBox(height: 16),

              // Education & Career
              if (((personalDetail['educationmedium'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['educationtype'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['faculty'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['degree'] as String?)?.isNotEmpty == true) ||
                  ((personalDetail['areyouworking'] as String?)?.isNotEmpty == true))
                _buildSectionCard(
                  title: 'Education & Career',
                  icon: Icons.school_outlined,
                  color: isDark ? Colors.green : Colors.green,
                  iconColor: Colors.green,
                  isDark: isDark,
                  children: [
                    if ((personalDetail['educationmedium'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Education Medium',
                        value: personalDetail['educationmedium'].toString(),
                        icon: Icons.menu_book_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['educationtype'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Education Type',
                        value: personalDetail['educationtype'].toString(),
                        icon: Icons.school_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['faculty'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Faculty',
                        value: personalDetail['faculty'].toString(),
                        icon: Icons.science_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['degree'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Degree',
                        value: personalDetail['degree'].toString(),
                        icon: Icons.workspace_premium_outlined,
                        isDark: isDark,
                      ),
                    if ((personalDetail['areyouworking'] as String?)?.isNotEmpty == true)
                      _buildInfoItem(
                        label: 'Working Status',
                        value: personalDetail['areyouworking'].toString(),
                        icon: Icons.work_outline,
                        isDark: isDark,
                      ),
                    if ((personalDetail['areyouworking'] as String?) == 'Yes') ...[
                      if ((personalDetail['occupationtype'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Occupation Type',
                          value: personalDetail['occupationtype'].toString(),
                          icon: Icons.business_center_outlined,
                          isDark: isDark,
                        ),
                      if ((personalDetail['companyname'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Company Name',
                          value: personalDetail['companyname'].toString(),
                          icon: Icons.business_outlined,
                          isDark: isDark,
                        ),
                      if ((personalDetail['designation'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Designation',
                          value: personalDetail['designation'].toString(),
                          icon: Icons.badge_outlined,
                          isDark: isDark,
                        ),
                      if ((personalDetail['workingwith'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Working With',
                          value: personalDetail['workingwith'].toString(),
                          icon: Icons.people_outline,
                          isDark: isDark,
                        ),
                      if ((personalDetail['annualincome'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Annual Income',
                          value: personalDetail['annualincome'].toString(),
                          icon: Icons.attach_money_outlined,
                          isDark: isDark,
                        ),
                      if ((personalDetail['businessname'] as String?)?.isNotEmpty == true)
                        _buildInfoItem(
                          label: 'Business Name',
                          value: personalDetail['businessname'].toString(),
                          icon: Icons.store_outlined,
                          isDark: isDark,
                        ),
                    ],
                  ],
                ),

              // About Me
              if ((personalDetail['aboutMe'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildTextCard(
                  title: 'About Me',
                  content: personalDetail['aboutMe'].toString(),
                  icon: Icons.edit_note_outlined,
                  iconColor: Colors.red,
                  isDark: isDark, color: Colors.red,
                ),
              ],
              const SizedBox(height: 20),



    _buildSectionCard(
    title: 'Family Background',
    icon: Icons.home_outlined,
    color: isDark ? Colors.purple! : Colors.purple,
    iconColor: Colors.purple,
    isDark: isDark,
    children: [
    if ((familyDetail['familytype'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Family Type',
    value: familyDetail['familytype'].toString(),
    icon: Icons.house_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['familybackground'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Family Background',
    value: familyDetail['familybackground'].toString(),
    icon: Icons.history_edu_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['familyorigin'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Family Origin',
    value: familyDetail['familyorigin'].toString(),
    icon: Icons.place_outlined,
    isDark: isDark,
    ),
    ],
    ),
    const SizedBox(height: 16),

    // Father Details
    if (((familyDetail['fathername'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['fatherstatus'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['fathereducation'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['fatheroccupation'] as String?)?.isNotEmpty == true))
    _buildSectionCard(
    title: 'Father Details',
    icon: Icons.man_outlined,
    color: isDark ? Colors.blue : Colors.blue,
    iconColor: Colors.blue,
    isDark: isDark,
    children: [

    if ((familyDetail['fatherstatus'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Status',
    value: familyDetail['fatherstatus'].toString(),
    icon: Icons.health_and_safety_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['fathereducation'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Education',
    value: familyDetail['fathereducation'].toString(),
    icon: Icons.school_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['fatheroccupation'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Occupation',
    value: familyDetail['fatheroccupation'].toString(),
    icon: Icons.work_outline,
    isDark: isDark,
    ),
    ],
    ),

    if (
    ((familyDetail['fatherstatus'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['fathereducation'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['fatheroccupation'] as String?)?.isNotEmpty == true))
    const SizedBox(height: 16),

    // Mother Details
    if (((familyDetail['motherstatus'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['mothercaste'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['mothereducation'] as String?)?.isNotEmpty == true) ||
    ((familyDetail['motheroccupation'] as String?)?.isNotEmpty == true))
    _buildSectionCard(
    title: 'Mother Details',
    icon: Icons.woman_outlined,
    color: isDark ? Colors.pink : Colors.pink,
    iconColor: Colors.pink,
    isDark: isDark,
    children: [
    if ((familyDetail['motherstatus'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Status',
    value: familyDetail['motherstatus'].toString(),
    icon: Icons.health_and_safety_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['mothercaste'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Caste',
    value: familyDetail['mothercaste'].toString(),
    icon: Icons.groups_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['mothereducation'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Education',
    value: familyDetail['mothereducation'].toString(),
    icon: Icons.school_outlined,
    isDark: isDark,
    ),
    if ((familyDetail['motheroccupation'] as String?)?.isNotEmpty == true)
    _buildInfoItem(
    label: 'Occupation',
    value: familyDetail['motheroccupation'].toString(),
    icon: Icons.work_outline,
    isDark: isDark,
    ),
      SizedBox(height: 20,),

      _buildSectionCard(
        title: 'Diet & Habits',
        icon: Icons.restaurant_menu_outlined,
        color: isDark ? Colors.green : Colors.green,
        iconColor: Colors.green,
        isDark: isDark,
        children:
        [
          if ((lifestyle['diet'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Diet',
              value: lifestyle['diet'].toString(),
              icon: Icons.restaurant_outlined,
              isDark: isDark,
            ),
          if ((lifestyle['smoke'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Smoking',
              value: lifestyle['smoke'].toString(),
              icon: Icons.smoking_rooms_outlined,
              isDark: isDark,
            ),
          if ((lifestyle['smoke'] as String?) == 'Yes' &&
              (lifestyle['smoketype'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Smoking Type',
              value: lifestyle['smoketype'].toString(),
              icon: Icons.smoke_free_outlined,
              isDark: isDark,
            ),
          if ((lifestyle['drinks'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Drinking',
              value: lifestyle['drinks'].toString(),
              icon: Icons.local_bar_outlined,
              isDark: isDark,
            ),
          if ((lifestyle['drinks'] as String?) == 'Yes' &&
              (lifestyle['drinktype'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Drinking Type',
              value: lifestyle['drinktype'].toString(),
              icon: Icons.liquor_outlined,
              isDark: isDark,
            ),
        ],


      ),
      SizedBox(height: 20,),
      _buildSectionCard(
        title: 'Partner Preferences',
        icon: Icons.filter_list_outlined,
        color: isDark ? Colors.red : Colors.red,
        iconColor: Colors.red,
        isDark: isDark,
        children:
        [
          if (partner['minage'] != null && partner['maxage'] != null)
            _buildInfoItem(
              label: 'Age Range',
              value: '${partner['minage']} - ${partner['maxage']} years',
              icon: Icons.cake_outlined,
              isDark: isDark,
            ),
          if (partner['minweight'] != null && partner['maxweight'] != null)
            _buildInfoItem(
              label: 'Weight Range',
              value: '${partner['minweight']} - ${partner['maxweight']} kg',
              icon: Icons.monitor_weight_outlined,
              isDark: isDark,
            ),
          if ((partner['maritalstatus'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Marital Status',
              value: partner['maritalstatus'].toString(),
              icon: Icons.favorite_border_outlined,
              isDark: isDark,
            ),
          if ((partner['profilewithchild'] as String?)?.isNotEmpty == true)
            _buildInfoItem(
              label: 'Profile with Child',
              value: partner['profilewithchild'].toString(),
              icon: Icons.child_friendly_outlined,
              isDark: isDark,
            ),

          SizedBox(height: 20,),
          const SizedBox(height: 16),

          // Religious Preferences
          if (((partner['religion'] as String?)?.isNotEmpty == true) ||
              ((partner['caste'] as String?)?.isNotEmpty == true) ||
              ((partner['mothertoungue'] as String?)?.isNotEmpty == true) ||
              ((partner['herscopeblief'] as String?)?.isNotEmpty == true) ||
              ((partner['manglik'] as String?)?.isNotEmpty == true))
            _buildSectionCard(
              title: 'Religious Preferences',
              icon: Icons.temple_hindu_outlined,
              color: isDark ? Colors.orange : Colors.orange,
              iconColor: Colors.orange,
              isDark: isDark,
              children:
              [
                if ((partner['religion'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Religion',
                    value: partner['religion'].toString(),
                    icon: Icons.mosque_outlined,
                    isDark: isDark,
                  ),
                if ((partner['caste'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Caste',
                    value: partner['caste'].toString(),
                    icon: Icons.groups_outlined,
                    isDark: isDark,
                  ),
                if ((partner['mothertoungue'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Mother Tongue',
                    value: partner['mothertoungue'].toString(),
                    icon: Icons.language_outlined,
                    isDark: isDark,
                  ),
                if ((partner['herscopeblief'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Horoscope Belief',
                    value: partner['herscopeblief'].toString(),
                    icon: Icons.psychology_outlined,
                    isDark: isDark,
                  ),
                if ((partner['manglik'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Manglik',
                    value: partner['manglik'].toString(),
                    icon: Icons.spa_outlined,
                    isDark: isDark,
                  ),
              ],
            ),

          if (((partner['religion'] as String?)?.isNotEmpty == true) ||
              ((partner['caste'] as String?)?.isNotEmpty == true) ||
              ((partner['mothertoungue'] as String?)?.isNotEmpty == true) ||
              ((partner['herscopeblief'] as String?)?.isNotEmpty == true) ||
              ((partner['manglik'] as String?)?.isNotEmpty == true))
            const SizedBox(height: 16),

          // Location Preferences
          if (((partner['country'] as String?)?.isNotEmpty == true) ||
              ((partner['state'] as String?)?.isNotEmpty == true) ||
              ((partner['city'] as String?)?.isNotEmpty == true))
            _buildSectionCard(
              title: 'Location Preferences',
              icon: Icons.location_on_outlined,
              color: isDark ? Colors.blue : Colors.blue,
              iconColor: Colors.blue,
              isDark: isDark,
              children:
              [
                if ((partner['country'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'Country',
                    value: partner['country'].toString(),
                    icon: Icons.public_outlined,
                    isDark: isDark,
                  ),
                if ((partner['state'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'State',
                    value: partner['state'].toString(),
                    icon: Icons.map_outlined,
                    isDark: isDark,
                  ),
                if ((partner['city'] as String?)?.isNotEmpty == true)
                  _buildInfoItem(
                    label: 'City',
                    value: partner['city'].toString(),
                    icon: Icons.location_city_outlined,
                    isDark: isDark,
                  ),
              ],
            ),

          if (((partner['country'] as String?)?.isNotEmpty == true) ||
              ((partner['state'] as String?)?.isNotEmpty == true) ||
              ((partner['city'] as String?)?.isNotEmpty == true))
            const SizedBox(height: 16),

          // Other Sections...
          // Note: I've condensed for brevity, but you would continue the pattern
          // Add Education & Career, Lifestyle Preferences, Physical Preferences sections

          // Other Expectations
          if ((partner['otherexpectation'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildTextCard(
              title: 'Other Expectations',
              content: partner['otherexpectation'].toString(),
              icon: Icons.star_outline,
              color: isDark ? Colors.red : Colors.red,
              iconColor: Colors.red,
              isDark: isDark,
            ),
            SizedBox(height: 70,),
          ],
        ],
      ),

    ],
    ) ]),
          ),
        ),
      ],
    );
  }




}