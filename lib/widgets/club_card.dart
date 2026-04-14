import 'package:flutter/material.dart';
import '../models/club_model.dart';
import '../theme/app_theme.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;

  const ClubCard({super.key, required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap, // This is passed from ClubsScreen
          child: Column(
            children: [
              // Top Section (Icon Placeholder)
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFE8EAF6),
                  child: Center(
                    child: Text(
                      // Safety check: if name is empty, show '?' instead of crashing
                      club.name.isNotEmpty ? club.name[0].toUpperCase() : '?', 
                      style: const TextStyle(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold, 
                        color: AppTheme.primaryBlue
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Section (Info)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        club.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        club.category,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}