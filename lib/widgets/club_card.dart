import 'package:flutter/material.dart';
import '../models/club_model.dart';
import '../theme/app_theme.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final VoidCallback onJoin;
  final VoidCallback onDetails;

  const ClubCard({
    super.key,
    required this.club,
    required this.onJoin,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = club.maxMembers > 0
        ? (club.memberCount / club.maxMembers).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image with category badge overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: club.imageUrl.isNotEmpty
                    ? Image.network(
                        club.imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderBanner(),
                      )
                    : _buildPlaceholderBanner(),
              ),
              // Category badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    club.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club name
                Text(
                  club.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  club.description.isNotEmpty
                      ? club.description
                      : 'No description available.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Recruitment status + member count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: club.recruitmentOpen
                                ? const Color(0xFF6C63FF)
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          club.recruitmentOpen
                              ? 'Recruitment Open'
                              : 'Recruitment Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: club.recruitmentOpen
                                ? const Color(0xFF6C63FF)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${club.memberCount}/${club.maxMembers} members',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Member progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Join Club',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 170,
      width: double.infinity,
      color: const Color(0xFF1A237E),
      child: Center(
        child: Text(
          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
