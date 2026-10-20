import 'dart:math' as math;

import '../../models/investment_command_models.dart';

class InvestmentCalculationService {
  /// Calculates standard SIP projection with milestone breakdown
  static SipCalculationResult calculateSip({
    required double monthlySip,
    required int durationYears,
    required double annualReturnRate,
    double startingInvestment = 0.0,
  }) {
    final int months = durationYears * 12;
    final double monthlyRate = annualReturnRate / 12.0 / 100.0;

    double corpusFromSip = 0.0;
    if (monthlyRate > 0) {
      corpusFromSip =
          monthlySip *
          ((math.pow(1.0 + monthlyRate, months) - 1.0) / monthlyRate) *
          (1.0 + monthlyRate);
    } else {
      corpusFromSip = monthlySip * months;
    }

    final double corpusFromStarting =
        startingInvestment *
        math.pow(1.0 + (annualReturnRate / 100.0), durationYears);
    final double totalEstimatedCorpus = corpusFromSip + corpusFromStarting;
    final double totalInvested = (monthlySip * months) + startingInvestment;
    final double estimatedGain = (totalEstimatedCorpus - totalInvested).clamp(
      0.0,
      double.infinity,
    );

    // Conservative (-3%) and Optimistic (+3%) bands
    final double conservativeRate = (annualReturnRate - 3.0).clamp(4.0, 30.0);
    final double optimisticRate = (annualReturnRate + 3.0).clamp(6.0, 35.0);

    final double consMonthlyRate = conservativeRate / 12.0 / 100.0;
    final double optMonthlyRate = optimisticRate / 12.0 / 100.0;

    final double conservativeCorpus =
        (monthlySip *
            ((math.pow(1.0 + consMonthlyRate, months) - 1.0) /
                consMonthlyRate) *
            (1.0 + consMonthlyRate)) +
        (startingInvestment *
            math.pow(1.0 + (conservativeRate / 100.0), durationYears));

    final double optimisticCorpus =
        (monthlySip *
            ((math.pow(1.0 + optMonthlyRate, months) - 1.0) / optMonthlyRate) *
            (1.0 + optMonthlyRate)) +
        (startingInvestment *
            math.pow(1.0 + (optimisticRate / 100.0), durationYears));

    // Calculate milestone points for each year
    final List<SipMilestone> milestones = [];
    for (int y = 1; y <= durationYears; y++) {
      final int mCount = y * 12;
      final double investedY = (monthlySip * mCount) + startingInvestment;
      final double corpusY =
          (monthlySip *
              ((math.pow(1.0 + monthlyRate, mCount) - 1.0) / monthlyRate) *
              (1.0 + monthlyRate)) +
          (startingInvestment * math.pow(1.0 + (annualReturnRate / 100.0), y));
      milestones.add(
        SipMilestone(
          year: y,
          totalInvested: investedY,
          estimatedCorpus: corpusY,
          estimatedGain: (corpusY - investedY).clamp(0.0, double.infinity),
        ),
      );
    }

    return SipCalculationResult(
      monthlySip: monthlySip,
      durationYears: durationYears,
      annualReturnRate: annualReturnRate,
      startingInvestment: startingInvestment,
      totalInvested: totalInvested,
      estimatedGain: estimatedGain,
      estimatedCorpus: totalEstimatedCorpus,
      conservativeCorpus: conservativeCorpus,
      optimisticCorpus: optimisticCorpus,
      milestones: milestones,
    );
  }

  /// Calculates Lump Sum growth and compares to equivalent SIP
  static LumpSumCalculationResult calculateLumpSum({
    required double initialInvestment,
    required int durationYears,
    required double annualReturnRate,
  }) {
    final double rateFraction = annualReturnRate / 100.0;
    final double estimatedCorpus =
        initialInvestment * math.pow(1.0 + rateFraction, durationYears);
    final double estimatedGain = (estimatedCorpus - initialInvestment).clamp(
      0.0,
      double.infinity,
    );

    // Equivalent monthly SIP that would yield the exact same corpus in same years
    final int months = durationYears * 12;
    final double monthlyRate = annualReturnRate / 12.0 / 100.0;
    double sipEquivalent = 0.0;
    if (monthlyRate > 0 && months > 0) {
      final double fvFactor =
          ((math.pow(1.0 + monthlyRate, months) - 1.0) / monthlyRate) *
          (1.0 + monthlyRate);
      sipEquivalent = estimatedCorpus / fvFactor;
    }

    return LumpSumCalculationResult(
      initialInvestment: initialInvestment,
      durationYears: durationYears,
      annualReturnRate: annualReturnRate,
      totalInvested: initialInvestment,
      estimatedGain: estimatedGain,
      estimatedCorpus: estimatedCorpus,
      sipEquivalentMonthly: sipEquivalent,
    );
  }

  /// Reverse calculates how much monthly contribution is required to reach a specific target corpus
  static GoalSipRequirementResult calculateGoalSipRequirement({
    required double targetCorpus,
    required double currentCorpus,
    required int durationYears,
    required double annualReturnRate,
    required double availableMonthlyCapacity,
  }) {
    final int months = durationYears * 12;
    final double monthlyRate = annualReturnRate / 12.0 / 100.0;

    // Projected value of current corpus with compound interest
    final double futureCurrentCorpus =
        currentCorpus *
        math.pow(1.0 + (annualReturnRate / 100.0), durationYears);

    final double remainingCorpusNeeded = (targetCorpus - futureCurrentCorpus)
        .clamp(0.0, targetCorpus);

    double requiredMonthly = 0.0;
    if (remainingCorpusNeeded > 0 && months > 0) {
      if (monthlyRate > 0) {
        final double fvFactor =
            ((math.pow(1.0 + monthlyRate, months) - 1.0) / monthlyRate) *
            (1.0 + monthlyRate);
        requiredMonthly = remainingCorpusNeeded / fvFactor;
      } else {
        requiredMonthly = remainingCorpusNeeded / months;
      }
    }

    final double gap = availableMonthlyCapacity - requiredMonthly;
    final bool isAchievable = gap >= 0;

    final List<String> alternatives = [];
    if (!isAchievable) {
      final double shortfall = -gap;
      alternatives.add(
        'Increase monthly investment capacity by ₹${shortfall.toStringAsFixed(0)} through spending reductions.',
      );
      alternatives.add(
        'Extend goal horizon by 1 to 2 years to allow compounding to carry more weight.',
      );
      alternatives.add(
        'Contribute a one-time lump sum from bonus or maturing deposits to lower monthly demands.',
      );
      alternatives.add(
        'Calibrate target budget downwards to an achievable intermediate milestone.',
      );
      alternatives.add(
        'Consider a balanced portfolio asset allocation to capture higher long-term compounding.',
      );
    } else {
      alternatives.add(
        'Maintain consistent SIP automated on the 1st week of every month.',
      );
      alternatives.add(
        'Step up SIP by 10% annually with every salary increment to finish ahead of schedule.',
      );
      alternatives.add(
        'Allocate any surplus above required investment into long-term wealth creation.',
      );
    }

    return GoalSipRequirementResult(
      targetCorpus: targetCorpus,
      currentCorpus: currentCorpus,
      durationYears: durationYears,
      annualReturnRate: annualReturnRate,
      requiredMonthlyInvestment: requiredMonthly,
      availableMonthlyCapacity: availableMonthlyCapacity,
      gap: gap,
      isAchievable: isAchievable,
      strategicAlternatives: alternatives,
    );
  }
}
