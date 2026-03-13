# Test Harness Plan for JamesIves/hlds-docker Evaluation

## Overview
This document outlines the test harness workflow for evaluating the JamesIves/hlds-docker image on the LAN server. The goal is to determine if this image can replace our current buggy `blsalin/rehlds-cstrike` base image.

## Server Environment
- **Repository Path**: `/srv/rehlds-cstrike-reunion`
- **Test Directory**: `/srv/rehlds-cstrike-reunion/hlds-jamesives-test`
- **Server Access**: SSH to "lan" host

## Workflow Loop

### Phase 1: Preparation (Local Development)
1. **Create/Update Test Files** locally in `hlds-jamesives-test/`
2. **Commit and Push** changes to repository
3. **Sync to Server**:
   ```bash
   ssh lan "cd /srv/rehlds-cstrike-reunion && git pull"
   ```

### Phase 2: Execution (Server Testing)
4. **Run Automated Tests**:
   ```bash
   ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && bash test_jamesives.sh"
   ```

### Phase 3: Analysis (Local Review)
5. **Collect Test Results** from server output
6. **Analyze Results**:
   - Did `aim_headshot` load successfully?
   - Did it stay on `aim_headshot` or fall back to `de_dust2`?
   - Any `CWorkThreadPool` errors?
   - Server stability indicators

### Phase 4: Iteration (Based on Results)
7. **Modify Test Files** based on results
8. **Repeat from Phase 1**

## Test Sequence

### Initial Test (Baseline)
```bash
# Pull image and run basic tests
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && bash test_jamesives.sh"
```

### Expected Test Flow
1. **Test 1**: `de_dust2` (should work - baseline)
2. **Test 2**: `cs_italy` (should work - standard map)
3. **Test 3**: `aim_headshot` (CRITICAL - custom aim map)

### Success Criteria
- ✅ `Mapchange to aim_headshot` appears in logs
- ✅ NO `Mapchange to de_dust2` after `aim_headshot`
- ✅ Server stays on specified map
- ✅ NO `CWorkThreadPool` errors
- ✅ Server shows `Connection to Steam servers successful`

### Failure Indicators
- ❌ `Mapchange to de_dust2` appears after `aim_headshot`
- ❌ `Couldn't spawn server maps/aim_headshot.bsp`
- ❌ `CWorkThreadPool` errors
- ❌ Server crashes/restarts

## Iteration Scenarios

### Scenario A: Tests PASS ✅
**Next Steps**:
1. Create new Dockerfile based on `jives/hlds:cstrike`
2. Add AMX Mod X, ReDeathmatch, etc.
3. Test plugin compatibility
4. Begin migration process

### Scenario B: Tests FAIL - Map not found ❌
**Debug Steps**:
1. Check if map files exist on server:
   ```bash
   ssh lan "ls -la /srv/rehlds-cstrike-reunion/docker-assets/maps/ | grep aim_headshot"
   ```
2. Verify volume mounts in test script
3. Check Docker container logs for path errors

### Scenario C: Tests FAIL - Falls back to de_dust2 ❌
**Debug Steps**:
1. Try legacy version: `jives/hlds:cstrike-legacy`
2. Check server logs for crash indicators
3. Test with different custom maps
4. Review JamesIves documentation for known issues

### Scenario D: Tests FAIL - Other errors ❌
**Debug Steps**:
1. Capture full logs:
   ```bash
   ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && docker logs cs16-test-aim_headshot 2>&1 | tail -100"
   ```
2. Check Docker daemon logs
3. Verify server resources (memory, disk space)

## Quick Commands Reference

### Git Sync
```bash
# Push local changes
git add hlds-jamesives-test/
git commit -m "Update JamesIves test files"
git push

# Pull on server
ssh lan "cd /srv/rehlds-cstrike-reunion && git pull"
```

### Test Execution
```bash
# Full test suite
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && bash test_jamesives.sh"

# Single test (manual)
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && docker run ... +map aim_headshot"

# Check logs
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && docker logs cs16-test-aim_headshot --tail 50"
```

### Cleanup
```bash
# Clean test containers
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && docker ps -a | grep cs16-test | awk '{print \$1}' | xargs -r docker rm -f"

# Clean all containers
ssh lan "docker ps -aq | xargs -r docker rm -f 2>/dev/null || true"
```

## Monitoring and Logging

### Key Log Patterns to Watch
- `Mapchange to [mapname]` - Map loading events
- `Connection to Steam servers successful` - Server ready
- `VAC secure mode is activated` - Security enabled
- `CWorkThreadPool` - Error indicator (bad)
- `Couldn't spawn server` - Map file error
- `Auto-restarting the server on crash` - Crash indicator

### Log Collection Commands
```bash
# Get test results
ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && bash test_jamesives.sh 2>&1"

# Get specific container logs
ssh lan "docker logs cs16-test-aim_headshot 2>&1 | grep -A5 -B5 'Mapchange'"

# Get all container logs
ssh lan "docker ps -a | grep cs16-test | awk '{print \$1}' | while read cid; do echo \"=== \$cid ===\"; docker logs \$cid 2>&1 | tail -20; done"
```

## Timeline and Milestones

### Day 1: Initial Testing
1. Deploy test files to server
2. Run baseline tests
3. Document results
4. Plan next steps

### Day 2: Debugging (if needed)
1. Address any test failures
2. Try alternative approaches
3. Gather more detailed logs
4. Update test harness

### Day 3: Decision Point
1. Evaluate all test results
2. Decide: Migrate to JamesIves or alternative
3. Create implementation plan
4. Begin migration if viable

## Risk Mitigation

### Technical Risks
1. **JamesIves image incompatible** - Fallback: Try legacy version or other images
2. **Plugin compatibility issues** - Fallback: Test plugins incrementally
3. **Performance differences** - Fallback: Benchmark and optimize

### Operational Risks
1. **Server downtime during tests** - Mitigation: Use non-production ports
2. **Data loss** - Mitigation: Backup configurations before changes
3. **Network issues** - Mitigation: Test during low-traffic periods

## Success Metrics
1. **Technical**: Server loads and stays on specified maps
2. **Performance**: Server stable for 24+ hours
3. **Functional**: All plugins work correctly
4. **User**: Players can connect and play normally

## Communication Plan
- **Daily Updates**: Share test results and next steps
- **Decision Points**: Document rationale for migration decisions
- **Issue Tracking**: Log all test failures and resolutions
- **Documentation**: Update all relevant docs with findings

## Next Immediate Actions
1. [ ] Push current test files to repository
2. [ ] Sync to server: `ssh lan "cd /srv/rehlds-cstrike-reunion && git pull"`
3. [ ] Run initial tests: `ssh lan "cd /srv/rehlds-cstrike-reunion/hlds-jamesives-test && bash test_jamesives.sh"`
4. [ ] Analyze results and plan next iteration

---
**Last Updated**: $(date)
**Maintainer**: [Your Name]
**Status**: Ready for Initial Testing
