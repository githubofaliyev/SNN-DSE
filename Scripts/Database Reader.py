import optuna
import os


study_path = "./Lapicque/DVSGesture Binary/FS 08_30_2024-06_27_50_PM/FS 08_30_2024-06_27_50_PM"
storage_name = "sqlite:///{}.db".format(study_path)

# print(os.path.isfile(study_path+".db"))
# print(optuna.study.get_all_study_names(storage_name))

study = optuna.load_study(study_name="FS 08_30_2024-06_27_50_PM", storage=storage_name)
# new_study = optuna.create_study(study_name="Leaky Spike Operator", storage="sqlite:///./NMNIST Binary/Leaky Spike Operator 08_13_2024-02_45_54_PM/Leaky Spike Operator.db", direction="maximize",
#                                 pruner=optuna.pruners.NopPruner())

# new_study.add_trials(study.trials[:11])

# Sort trials based on their objective value
sorted_trials = sorted(study.get_trials(deepcopy=False, states=[optuna.trial.TrialState.COMPLETE]), key=lambda t: t.value, reverse=True)

# Get the top 10 trials
top_6_trials = sorted_trials

# Print information about the top 10 trials
for i, trial in enumerate(top_6_trials, 1):
    print(f"Rank {i}:")
    print(f"  Trial number: {trial.number}")
    print(f"  Objective value: {trial.value:0.2f}")
    print(f"  Parameters: {trial.params}")
    print()
