# -*- coding: utf-8 -*-
"""
Unit Base of Physical Quantities
--------------------------------
Created on 27.01.2019 by Ismail Baris

This Module is the base for expression decompositions and unit and dimension based operations of `Quantity` objects.
"""
from __future__ import division
import numpy as np
cimport numpy as np
from respy.units.util import UnitError, __UNITS__, Zero, One
from respy.units.dimensions import area, volume, length
import sympy
from respy.units.auxil import __NONE_UNITS__

cdef:
    list __OPERATION_LIST__ = ['*', '/', '+', '-', '**']

ctypedef fused DTYPE_SCALAR:
    int
    double
    long long
    float

ctypedef fused DTYPE_ARRAY:
    np.ndarray
    int[:]
    double[:]
    long long[:]
    float[:]
    int[:,:]
    double[:,:]
    long long[:,:]
    float[:,:]
    int[:,:,:]
    double[:,:,:]
    long long[:,:,:]
    float[:,:,:]

cdef object get_unit_from_str(char* unit):
    """
    Get a unit object from str or char.
    
    Parameters
    ----------
    unit : char*
        Desired unit in str format. 
        
    Returns
    -------
    object
    
    """
    cdef:
        list unit_list, operand_list
        object unit_obj
        Py_ssize_t i

    unit_str = unit.split()
    unit_list = []
    operand_list = []

    for item in unit_str:
        if item in __OPERATION_LIST__:
            operand_list.append(item)

        else:
            try:
                item = int(item)
                unit_list.append(item)

            except ValueError:
                try:
                    unit_list.append(__UNITS__[item])

                except KeyError:
                    raise UnitError("{} is not a valid unit.".format(str(item)))

    unit_obj = unit_list[0]

    for i in range(1, len(unit_list)):
        item = unit_list[i]
        try:
            if operand_list[i - 1] == b'*':
                unit_obj *= item
            elif operand_list[i - 1] == b'/':
                unit_obj /= item
            elif operand_list[i - 1] == b'+':
                unit_obj += item
            elif operand_list[i - 1] == b'-':
                unit_obj -= item
            elif operand_list[i - 1] == b'**':
                unit_obj **= item
        except IndexError:
            pass

    return unit_obj


cdef tuple decompose_expr(object expr):
    """
    Decompose a sympy expression to value and units.
    
    Parameters
    ----------
    expr : sympy expression
        A sympy expression.
        
    Returns
    -------
    tuple (DTYPE_SCALAR value, object unit)
    """
    cdef:
        Py_ssize_t i
        object unit_obj
        tuple unit

    if 'Pow' in str(type(expr)):
        value = 1
        unit_obj = expr

    elif 'Mul' in str(type(expr)):
        value = expr.args[0]

        try:
            value = float(value)
            unit = expr.args[1:]

            if len(unit) == 1:
                unit_obj = unit[0]
            else:
                unit_obj = unit[0]

                for i in range(1, len(unit)):
                    unit_obj *= unit[i]

        except TypeError:
            value = 1
            unit_obj = expr

    else:
        raise TypeError("Data type {0} not understood.".format(str(expr)))

    return value, unit_obj

def get_dimension(unit):
    cdef:
        object dimension, unit_base

    unit = get_unit(unit)

    if 'Quantity' in str(type(unit)):
        try:
            dimension = unit.dimension

            if dimension.name == One:
                dimension = Zero
            else:
                pass

        except AttributeError:
            dimension = Zero

    elif 'Pow' in str(type(unit)):
        unit_base, exp = unit.args

        try:
            dimension_base = unit_base.dimension

            if dimension_base == length:

                if exp == 2:
                    dimension = area
                elif exp == 3:
                    dimension = volume
                else:
                    dimension = Zero
            else:
                dimension = Zero

        except AttributeError:
            dimension = Zero

    else:
        dimension = Zero

    return dimension

cdef tuple decompose_expr_array(value):
    """
    Decompose a array with sympy expressions to value and units.
    
    Parameters
    ----------
    value : numpy.ndarray
        An array with sympy expressions.
        
    Returns
    -------
    tuple (DTYPE_ARRAY value, object unit)
    """

    cdef:
        tuple shape
        # DTYPE_ARRAY value_flatten
        Py_ssize_t i

    shape = value.shape
    value_flatten = value.flatten()

    value = np.zeros_like(value_flatten)
    unit = np.zeros_like(value_flatten, dtype=np.object)

    for i, item in enumerate(value_flatten):
        value[i], unit[i] = decompose_expr(item)

    value = value.reshape(shape)
    unit = unit.reshape(shape)

    if np.any(unit[0] == unit):
        value = value.astype(np.double)
        return value, unit[0]
    else:
        raise ValueError("If the input is an array, the units for all values must be equal.")

def get_unit(unit):
    """
    Get unit object from string or unit object.

    Parameters
    ----------
    unit : str, char or unit object.

    Returns
    -------
    object
    """
    if isinstance(unit, tuple(sympy.core.all_classes)):
        return unit
    elif isinstance(unit, str):
        return get_unit_from_str(unit)
    elif unit in __NONE_UNITS__:
        return Zero
    else:
        raise UnitError("{} is not a valid unit.".format(str(unit)))

def decompose_expr_to_atoms(value):
    """
    Decompose a array with sympy expressions or a sympy expression to value and units.

    Parameters
    ----------
    value : numpy.ndarray, sympy expression
        An array with sympy expressions.

    Returns
    -------
    tuple (DTYPE_ARRAY/DTYPE_SCALAR value, object unit)
    """

    if isinstance(value, tuple(sympy.core.all_classes)):
        return decompose_expr(value)
    elif isinstance(value, np.ndarray):
        return decompose_expr_array(value)
    else:
        raise TypeError("{} is not a valid expression.".format(str(value)))