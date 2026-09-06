%% BBO optimization of the FAHP-assisted WMPM objective function
% Decision vector:
% x(1) = f0
% x(2) = f1
% x(3) = g1
%
% Equality constraint:
% g0 = 0.9628987*f0
%
% Resulting reduced-order model:
% R2(s) = (g1*s + g0)/(s^2 + f1*s + f0)

clear;
clc;
close all;

%% Reproducibility
rng(1, 'twister');

%% BBO control parameters
populationSize = 50;
maximumIterations = 500;

%% Decision-variable bounds
% Modify the upper bounds according to the admissible parameter ranges
% specified in the manuscript.
%
% f0 > 0 and f1 > 0 enforce stability of:
% f(s) = s^2 + f1*s + f0

lowerBound = [1.0e-6, 1.0e-6, -1.0];
upperBound = [20.0,   20.0,    1.0];

%% Execute Brown-Bear Optimization
[bestPosition, bestFitness, convergence] = brownBearOptimization( ...
    @wmpmObjective, populationSize, maximumIterations, ...
    lowerBound, upperBound);

%% Extract the optimized parameters
f0Star = bestPosition(1);
f1Star = bestPosition(2);
g1Star = bestPosition(3);

% Exact enforcement of the gain-matching equality constraint
g0Star = 0.9628987*f0Star;

%% Construct the optimized reduced-order model
R2Star = tf([g1Star, g0Star], [1, f1Star, f0Star]);

%% Display optimization results
fprintf('\n====================================================\n');
fprintf('BROWN-BEAR OPTIMIZATION RESULTS\n');
fprintf('====================================================\n');
fprintf('Minimum objective value = %.12e\n', bestFitness);
fprintf('f0* = %.10f\n', f0Star);
fprintf('f1* = %.10f\n', f1Star);
fprintf('g0* = %.10f\n', g0Star);
fprintf('g1* = %.10f\n', g1Star);

fprintf('\nConstraint verification:\n');
fprintf('f0*f1              = %.10f > 0\n', f0Star*f1Star);
fprintf('f1                  = %.10f > 0\n', f1Star);
fprintf('g0 - 0.9628987*f0  = %.4e\n', ...
        g0Star - 0.9628987*f0Star);

fprintf('\nOptimized reduced-order model:\n');
R2Star

fprintf('Poles of the optimized model:\n');
disp(pole(R2Star));

%% Plot convergence curve
figure('Color', 'w', 'Position', [100, 100, 800, 500]);

semilogy(1:maximumIterations, convergence, ...
    'b-', 'LineWidth', 2);

grid on;
box on;

xlabel('Iteration', 'FontName', 'Times New Roman', ...
       'FontSize', 12);
ylabel('Best objective value, \itJ(M)', ...
       'FontName', 'Times New Roman', ...
       'FontSize', 12);
title('Convergence of Brown-Bear Optimization', ...
      'FontName', 'Times New Roman', ...
      'FontSize', 12);

set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);

% Uncomment to save as a vector PDF:
% exportgraphics(gcf, 'BBO_convergence.pdf', ...
%                'ContentType', 'vector');


%% ================================================================
%  BROWN-BEAR OPTIMIZATION FUNCTION
%  ================================================================
function [bestPosition, bestFitness, convergence] = ...
    brownBearOptimization(objectiveFunction, populationSize, ...
                          maximumIterations, lowerBound, upperBound)

    numberVariables = numel(lowerBound);

    lowerBound = reshape(lowerBound, 1, []);
    upperBound = reshape(upperBound, 1, []);

    %% Initialize brown-bear population
    population = lowerBound + rand(populationSize, numberVariables).* ...
                 (upperBound - lowerBound);

    fitness = inf(populationSize, 1);

    for i = 1:populationSize
        fitness(i) = objectiveFunction(population(i,:));
    end

    [bestFitness, bestIndex] = min(fitness);
    bestPosition = population(bestIndex,:);

    convergence = zeros(maximumIterations, 1);

    %% Main BBO iterations
    for iteration = 1:maximumIterations

        occurrenceFactor = iteration/maximumIterations;

        %% Determine current best and worst bears
        [~, bestIndex] = min(fitness);
        [~, worstIndex] = max(fitness);

        currentBest = population(bestIndex,:);
        currentWorst = population(worstIndex,:);

        %% --------------------------------------------------------
        % Pedal scent-marking phase
        % ---------------------------------------------------------
        oldPopulation = population;
        oldFitness = fitness;

        for i = 1:populationSize

            currentBear = oldPopulation(i,:);

            if occurrenceFactor <= 1/3
                % Stage 1: characteristic gait while walking
                alpha = rand(1, numberVariables);

                candidate = currentBear - ...
                    occurrenceFactor.*alpha.*currentBear;

            elseif occurrenceFactor <= 2/3
                % Stage 2: careful stepping
                beta1 = rand(1, numberVariables);
                stepFactor = beta1.*occurrenceFactor;

                % Step length is either 1 or 2
                stepLength = round(1 + rand);

                candidate = currentBear + stepFactor.* ...
                    (currentBest - stepLength.*currentWorst);

            else
                % Stage 3: twisting-feet behavior
                gamma = rand(1, numberVariables);

                angularVelocity = ...
                    2*pi*occurrenceFactor.*gamma;

                candidate = currentBear + ...
                    angularVelocity.*(currentBest-currentBear) - ...
                    angularVelocity.*(currentWorst-currentBear);
            end

            % Repair the variable-bound constraints
            candidate = max(candidate, lowerBound);
            candidate = min(candidate, upperBound);

            candidateFitness = objectiveFunction(candidate);

            % Greedy selection
            if candidateFitness < oldFitness(i)
                population(i,:) = candidate;
                fitness(i) = candidateFitness;
            else
                population(i,:) = oldPopulation(i,:);
                fitness(i) = oldFitness(i);
            end
        end

        %% Update the global best solution
        [iterationBestFitness, iterationBestIndex] = min(fitness);

        if iterationBestFitness < bestFitness
            bestFitness = iterationBestFitness;
            bestPosition = population(iterationBestIndex,:);
        end

        %% --------------------------------------------------------
        % Sniffing phase
        % ---------------------------------------------------------
        oldPopulation = population;
        oldFitness = fitness;

        for m = 1:populationSize

            % Select a second bear n, where n is not equal to m
            availableIndices = [1:m-1, m+1:populationSize];
            n = availableIndices(randi(numel(availableIndices)));

            lambda = rand(1, numberVariables);

            if oldFitness(m) < oldFitness(n)
                candidate = oldPopulation(m,:) + lambda.* ...
                    (oldPopulation(m,:) - oldPopulation(n,:));
            else
                candidate = oldPopulation(m,:) + lambda.* ...
                    (oldPopulation(n,:) - oldPopulation(m,:));
            end

            % Repair the variable-bound constraints
            candidate = max(candidate, lowerBound);
            candidate = min(candidate, upperBound);

            candidateFitness = objectiveFunction(candidate);

            % Greedy selection between the new and old solutions
            if candidateFitness < oldFitness(m)
                population(m,:) = candidate;
                fitness(m) = candidateFitness;
            else
                population(m,:) = oldPopulation(m,:);
                fitness(m) = oldFitness(m);
            end
        end

        %% Update the global best after sniffing
        [iterationBestFitness, iterationBestIndex] = min(fitness);

        if iterationBestFitness < bestFitness
            bestFitness = iterationBestFitness;
            bestPosition = population(iterationBestIndex,:);
        end

        convergence(iteration) = bestFitness;

        if mod(iteration, 25) == 0 || iteration == 1
            fprintf('Iteration %4d: Best J(M) = %.12e\n', ...
                    iteration, bestFitness);
        end
    end
end


%% ================================================================
%  FAHP-ASSISTED WMPM OBJECTIVE FUNCTION
%  ================================================================
function objectiveValue = wmpmObjective(x)

    %% Extract independent variables
    f0 = x(1);
    f1 = x(2);
    g1 = x(3);

    %% Enforce the equality constraint exactly
    g0 = 0.9628987*f0;

    %% Enforce strict Routh stability constraints
    if f0 <= 0 || f1 <= 0 || f0*f1 <= 0
        objectiveValue = 1.0e30;
        return;
    end

    %% Numerators of the normalized matching terms
    numerator1 = 2019*g0 - 496664*g1;
    numerator2 = 3336*g0;
    numerator3 = 601.4*g0 + 1057519*g1;
    numerator4 = 45.03*g0 - 10953.6*g1;
    numerator5 = g0 + 1155.53*g1;

    %% Denominators of the normalized matching terms
    denominator1 = -31.36*f0 + 3212.23*f1 + 28275;
    denominator2 = 3212.23*f0;
    denominator3 = -2.5442*f0 - 31.36*f1 - 56476.325;

    % This coefficient follows the supplied objective equation.
    denominator4 = -0.5655*f0 - 2.5442*f1 + 6277.07525;

    denominator5 = -0.05655*f1 - 65.343;

    denominators = [denominator1, denominator2, denominator3, ...
                    denominator4, denominator5];

    %% Protect the calculation from nearly zero denominators
    denominatorTolerance = 1.0e-10;

    if any(abs(denominators) < denominatorTolerance)
        objectiveValue = 1.0e30;
        return;
    end

    %% Normalized matching errors
    error1 = 1 - numerator1/denominator1;
    error2 = 1 - numerator2/denominator2;
    error3 = 1 - numerator3/denominator3;
    error4 = 1 - numerator4/denominator4;
    error5 = 1 - numerator5/denominator5;

    %% F-AHP-derived weights
    weights = [0.58936, 0.22369, 0.11030, 0.04886, 0.02779];

    %% Weighted multi-point matching objective
    objectiveValue = ...
        weights(1)*error1^2 + ...
        weights(2)*error2^2 + ...
        weights(3)*error3^2 + ...
        weights(4)*error4^2 + ...
        weights(5)*error5^2;

    %% Numerical safeguard
    if ~isfinite(objectiveValue) || ~isreal(objectiveValue)
        objectiveValue = 1.0e30;
    end
end