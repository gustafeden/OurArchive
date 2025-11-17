# OurArchive Documentation

Welcome to the OurArchive documentation hub. This directory contains all technical documentation for the project.

## Quick Navigation

### For New Developers
Start here to get up and running:
- [Quick Start Guide](../QUICK_START.md) - First-time setup and onboarding
- [Firebase Setup](FIREBASE_SETUP.md) - Complete Firebase configuration guide
- [Architecture Overview](ARCHITECTURE.md) - System design and widget library

### Core Documentation

#### Project Information
- **[Features](FEATURES.md)** - Complete feature documentation
- **[Roadmap](ROADMAP.md)** - Development phases and future plans
- **[Architecture](ARCHITECTURE.md)** - System design, widget library, patterns

#### Setup & Configuration
- **[Firebase Setup](FIREBASE_SETUP.md)** - Auth, Firestore rules, Storage, indexes
- **[Quick Start](../QUICK_START.md)** - Developer onboarding guide

### Development

#### Development Guidelines
- **[Testing](development/TESTING.md)** - Testing strategy and procedures
- **[Claude Guidelines](../CLAUDE.md)** - AI assistant workflow guidelines

### Archive

Historical documentation and implementation summaries:

#### Refactoring History (November 2025)
- [Phase 1 Refactoring](archive/2025-11-refactoring/phase-1.md) - Initial widget library (7 widgets, ~342 LOC reduction)
- [Phases 2 & 3 Refactoring](archive/2025-11-refactoring/phases-2-3.md) - Expanded widget library (9 widgets, ~683 LOC reduction)

#### Feature Implementation History
- [Book Scanning Feature](archive/BOOK_SCANNING_FEATURE.md) - ISBN lookup implementation
- [Fullscreen Photo Feature](archive/FULLSCREEN_PHOTO_FEATURE.md) - Photo viewer with zoom/pan
- [Profile Feature](archive/PROFILE_FEATURE.md) - User profile screen
- [Navigation Reorganization](archive/REORGANIZED_NAVIGATION.md) - Navigation flow changes
- [Item Creation Update](archive/ITEM_CREATION_UPDATE.md) - Dual FAB implementation

#### Project Milestones
- [Implementation Summary](archive/IMPLEMENTATION_SUMMARY.md) - Week 1 MVP build
- [Week 2 Features](archive/WEEK_2_FEATURES.md) - Email/password auth, member approval
- [Improvements Completed](archive/IMPROVEMENTS_COMPLETED.md) - Container validation, filters, item move
- [Fixes Applied](archive/FIXES_APPLIED.md) - Thumbnail fixes, scan features

#### Planning Documents
- [Original Plan](archive/ORIGINAL_PLAN.md) - Initial implementation specification

## Documentation Standards

When adding new documentation:

1. **Location Guidelines**
   - **Root:** User-facing docs (README.md, QUICK_START.md, CLAUDE.md)
   - **docs/:** Technical documentation, setup guides, feature docs
   - **docs/development/:** Development-specific guides (testing, contributing)
   - **docs/archive/:** Historical implementation summaries

2. **File Naming**
   - Use descriptive names: `FIREBASE_SETUP.md`, not `SETUP.md`
   - Archive files by date: `YYYY-MM-feature-name.md`
   - Use UPPERCASE for primary docs, lowercase for subdirectories

3. **Content Guidelines**
   - Include date on time-sensitive docs
   - Add clear headers and table of contents for long docs
   - Link to related documentation
   - Use code examples where helpful
   - Keep architectural docs current, archive implementation details

4. **Maintenance**
   - Update this index when adding new docs
   - Archive outdated implementation details
   - Keep setup guides current with codebase changes
   - Link from multiple locations when docs serve multiple purposes

## Finding Documentation

### By Topic

**Getting Started**
- Installation → [Quick Start](../QUICK_START.md)
- Firebase Config → [Firebase Setup](FIREBASE_SETUP.md)
- Understanding the codebase → [Architecture](ARCHITECTURE.md)

**Features**
- What features exist → [Features](FEATURES.md)
- What's planned → [Roadmap](ROADMAP.md)
- How widgets work → [Architecture](ARCHITECTURE.md)

**Development**
- Testing → [Testing Guide](development/TESTING.md)
- AI workflow → [Claude Guidelines](../CLAUDE.md)

**History**
- Recent changes → [Archive directory](archive/)
- Refactoring → [2025-11 Refactoring](archive/2025-11-refactoring/)

### By Role

**New Developer**
1. Read [Quick Start](../QUICK_START.md)
2. Review [Architecture](ARCHITECTURE.md)
3. Check [Features](FEATURES.md)
4. Set up Firebase via [Firebase Setup](FIREBASE_SETUP.md)

**Project Manager**
1. Review [Features](FEATURES.md)
2. Check [Roadmap](ROADMAP.md)
3. Browse [Archive](archive/) for implementation history

**QA/Tester**
1. Read [Testing Guide](development/TESTING.md)
2. Review [Features](FEATURES.md)
3. Reference feature docs in [Archive](archive/)

**Designer/UX**
1. Check [Features](FEATURES.md) for current UX
2. Review [Architecture](ARCHITECTURE.md) for widget library
3. See [Roadmap](ROADMAP.md) for planned features

## Contributing to Documentation

When you implement a new feature or make significant changes:

1. **Update Core Docs:** Modify relevant sections in FEATURES.md, ARCHITECTURE.md
2. **Archive Implementation Details:** Create `archive/YYYY-MM-DD-feature-name.md`
3. **Update This Index:** Add links in appropriate sections
4. **Update References:** Check other docs for outdated links

## Questions?

If you can't find what you're looking for:
- Check the [Archive](archive/) directory for historical context
- Review git history for relevant commits
- Ask the team or check project README

---

**Last Updated:** 2025-11-17
