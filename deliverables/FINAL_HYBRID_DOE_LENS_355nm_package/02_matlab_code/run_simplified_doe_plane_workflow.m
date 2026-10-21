function result=run_simplified_doe_plane_workflow()
%RUN_SIMPLIFIED_DOE_PLANE_WORKFLOW Formal flat-phase Gaussian DOE model.
% Re-optimizes the 16-level DOE, exports and validates the Sequential ZMX,
% then runs OpticStudio POP from the DOE input reference to the target.
simulate_final_hybrid_doe_lens();
export_zemax_sequential_prescription();
validate_zemax_2022R2();
result=run_zemax_pop_simplified_doe_input();
end
